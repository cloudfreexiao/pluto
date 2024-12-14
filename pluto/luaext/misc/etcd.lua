local skynet = require "skynet"
local crypt = require "skynet.crypt"
local httpc = require "http.httpc"
local json = require "json"

local encode_base64 = crypt.base64encode
local decode_base64 = crypt.base64decode
local decode_json = json.decode
local encode_json = json.encode

local sub_str = string.sub
local str_byte = string.byte
local str_char = string.char
local tinsert = table.insert
local random = math.random

local NONEXIST = "has no healthy etcd endpoint available"

local M = {}

local mt = {}
mt.__index = mt

local fail_hosts = {}   --响应失败的host列表

httpc.dns() -- 异步查询 dns，避免阻塞整个 skynet 的网络消息

local function url_decode(str)
    local str = str:gsub('+', ' ')
    return (str:gsub("%%(%x%x)", function(c)
                         return string.char(tonumber(c, 16))
                                 end))
end

local function url_encode(str)
    return (str:gsub("([^A-Za-z0-9%_%.%-%~])", function(v)
                         return string.upper(string.format("%%%02x", string.byte(v)))
                                               end))
end

local function tab_exist(val)
    if val and type(val) == "table" then
        if next(val) then
            return true
        end
    end
    return false
end

local function verify_key(key)
    if not key or #key == 0 then
        return false
    end
    return true
end

local function get_range_end(key)
    if #key == 0 then
        return str_char(0)
    end

    local last = sub_str(key, -1)
    key = sub_str(key, 1, #key-1)

    local ascii = str_byte(last) + 1
    local str   = str_char(ascii)

    return key .. str
end

local function tab_clone(T)
    local out = {}
    for k, v in pairs(T) do
        out[k] = v
    end
    return out
end

local function format_params(params)
    local paramsT = {}
	for k, v in pairs(params) do
		local key = tostring(k)
		local value = tostring(v)
        tinsert(paramsT, url_encode(key) .. "=" .. url_encode(value))
	end
	return table.concat(paramsT, "&")
end

local function serialize_and_encode_base64(value)
    value = encode_json(value)

    if not value then
        return false
    end
    return encode_base64(value)
end

local function get_real_key(prefix, key)
    return (type(prefix) == 'string' and prefix or "") .. key
end

function mt:refresh_jwt_token(timeout)
    local now = skynet.time()
    if self.jwt_token and now - self.last_auth_time < 60 * 3 + random(0, 60) then
        return true
    end

    local opts = {
        body = {
            name = self.user,
            password = self.password,
        }
    }

    local rspData = self:_request('POST', "/auth/authenticate", opts, timeout, true)
    if not rspData then
        skynet.error("ectd error refresh jwt token")
        return false
    end

    self.jwt_token = rspData.token
    self.last_auth_time = now
    return true
end

function mt:_get_target_status(etcd_host)
    if type(etcd_host) ~= "string" then
        return false
    end
    local fail_expired_time = fail_hosts[etcd_host]
    if fail_expired_time and fail_expired_time >= skynet.time() then
        return false
    else
        return true
    end
end

function mt:_report_failure(etcd_host)
    if type(etcd_host) ~= "string" then
        return false
    end
    fail_hosts[etcd_host] = skynet.time() + self.fail_time
end

function mt:_choose_endpoint()
    local hosts = self.hosts
    for _, host in ipairs(hosts) do
        if self:_get_target_status(host) then
            return host
        end
    end
    return false
end

function mt:_http_request_uri(method, action, recvheader, header, reqData)
    local reqHost = self:_choose_endpoint()
    if not reqHost then
        return false, NONEXIST
    end
    local success, status, rspData = pcall(httpc.request, method, reqHost, action, recvheader, header, reqData)
    -- Log.debug("request method:%s host:%s action:%s reqData:%s rspData:%s", method, reqHost, action, reqData, rspData)
    if not success then
        self:_report_failure(reqHost)
        return false, reqHost .. ":" .. (rspData or "")
    end
    if status >= 500 then
        self:_report_failure(reqHost)
        return false, "invalid response code: " .. status
    end
    return rspData
end

function mt:_request(method, action, opts, timeout, ignore_auth)
    opts = opts or {}

    action = self.full_prefix .. action
    if opts.query and next(opts.query) then
        action = action .. '?' .. format_params(opts.query)
    end

    local reqData
    if opts.body and next(opts.body) then
        reqData = encode_json(opts.body)
    end

    httpc.timeout = timeout and timeout * 100

	local header = {
		["content-type"] = "application/x-www-form-urlencoded"
	}

    if not ignore_auth then
        if not self:refresh_jwt_token(timeout and timeout * 100) then
            return false
        end
        header.Authorization = self.jwt_token
    end

    local max_retry = #self.hosts * self.max_fail + 1

    local recvheader = {}
    local rspData, error
    for i = 1, max_retry, 1 do
        rspData, error = self:_http_request_uri(method, action, recvheader, header, reqData)
        if rspData then
            break
        end

        if error == NONEXIST then
            return false
        end

        if i < max_retry then
            skynet.error("retrying ... ", error)
        end
    end

    if type(rspData) ~= "string" then
        return false
    end

    local result = decode_json(rspData)
    result.recvheader = recvheader
    return result
end

function mt:_set(key, value, attr)
    if not verify_key(key) then
        skynet.error("set key invalid")
        return false
    end
    key = encode_base64(key)

    value = serialize_and_encode_base64(value)
    if not value then
        skynet.error("set value invalid")
        return false
    end

    attr = attr or {}

    local lease
    if attr.lease then
        lease = attr.lease and attr.lease or 0
    end

    local prev_kv
    if attr.prev_kv then
        prev_kv = attr.prev_kv and true or false
    end

    local ignore_value
    if attr.ignore_value then
        ignore_value = attr.ignore_value and true or false
    end

    local ignore_lease
    if attr.ignore_lease then
        ignore_lease = attr.ignore_lease and true or false
    end

    local opts = {
        body = {
            key          = key,
            value        = value,
            lease        = lease,
            prev_kv      = prev_kv,
            ignore_value = ignore_value,
            ignore_lease = ignore_lease,
        },
    }

    local rspData = self:_request('POST', "/kv/put", opts, self.timeout)

    if not rspData then
        skynet.error("ectd error set rspData:%s, key:%s, value:%s", rspData, key, value)
        return false
    end
    return rspData
end

function mt:_get(key, attr)
    if not verify_key(key) then
        skynet.error("get key invalid")
        return false
    end

    key = encode_base64(key)

    attr = attr or {}

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local limit
    if attr.limit then
        limit = attr.limit and attr.limit or 0
    end

    local revision
    if attr.revision then
        revision = attr.revision and attr.revision or 0
    end

    local sort_order
    if attr.sort_order then
        sort_order = attr.sort_order and attr.sort_order or 0
    end

    local sort_target
    if attr.sort_target then
        sort_target = attr.sort_target and attr.sort_target or 0
    end

    local serializable
    if attr.serializable then
        serializable = attr.serializable and true or false
    end

    local keys_only
    if attr.keys_only then
        keys_only = attr.keys_only and true or false
    end

    local count_only
    if attr.count_only then
        count_only = attr.count_only and true or false
    end

    local min_mod_revision
    if attr.min_mod_revision then
        min_mod_revision = attr.min_mod_revision or 0
    end

    local max_mod_revision
    if attr.max_mod_revision then
        max_mod_revision = attr.max_mod_revision or 0
    end

    local min_create_revision
    if attr.min_create_revision then
        min_create_revision = attr.min_create_revision or 0
    end

    local max_create_revision
    if attr.max_create_revision then
        max_create_revision = attr.max_create_revision or 0
    end

    local opts = {
        body = {
            key                 = key,
            range_end           = range_end,
            limit               = limit,
            revision            = revision,
            sort_order          = sort_order,
            sort_target         = sort_target,
            serializable        = serializable,
            keys_only           = keys_only,
            count_only          = count_only,
            min_mod_revision    = min_mod_revision,
            max_mod_revision    = max_mod_revision,
            min_create_revision = min_create_revision,
            max_create_revision = max_create_revision
        }
    }

    local rspData = self:_request("POST", "/kv/range", opts, attr.timeout)

    if not tab_exist(rspData) then
        skynet.error("ectd error get rspData:%s, key:%s", rspData, key)
        return false
    end
    if rspData and rspData.kvs and next(rspData.kvs) then
        for _, kv in ipairs(rspData.kvs) do
            kv.key = decode_base64(kv.key)
            kv.value = decode_base64(kv.value or "")
            kv.value = decode_json(kv.value)
        end
    end

    return rspData
end

function mt:_delete(key, attr)
    if not verify_key(key) then
        skynet.error("delete key invalid")
        return false
    end
    key = encode_base64(key)

    attr = attr or {}

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local prev_kv
    if attr.prev_kv then
        prev_kv = attr.prev_kv and true or false
    end

    local opts = {
        body = {
            key       = key,
            range_end = range_end,
            prev_kv   = prev_kv,
        },
    }

    local rspData = self:_request("POST", "/kv/deleterange", opts, self.timeout)
    if not rspData then
        skynet.error("ectd error delete rspData:%s, key:%s", rspData, key)
        return false
    end
    return rspData
end

function mt:_txn(opts_arg, compare, success, failure)
    if #compare < 1 then
        skynet.error("compare couldn't be empty")
        return false
    end

    if (success == nil or #success < 1) and (failure == nil or #failure < 1) then
        skynet.error("success and failure couldn't be empty at the same time")
        return false
    end

    local timeout = opts_arg and opts_arg.timeout
    local opts = {
        body = {
            compare = compare,
            success = success,
            failure = failure,
        },
    }

    local rspData = self:_request("POST", "/kv/txn", opts, timeout or self.timeout)
    if not rspData then
        skynet.error("ectd error txn rspData:%s", rspData)
        return false
    end
    return rspData
end

function mt:_http_request_stream(method, action, recvheader, header, reqData)
    local reqHost = self:_choose_endpoint()
    if not reqHost then
        return false, NONEXIST
    end
    local success, stream = pcall(httpc.request_stream, method, reqHost, action, recvheader, header, reqData)
    -- skynet.error("request method:%s host:%s action:%s reqData:%s rspData:%s", method, reqHost, action, reqData, rspData)
    if not success then
        self:_report_failure(reqHost)
        return false, reqHost .. ": request_stream error"
    end
    return stream, nil, reqHost
end

function mt:_request_stream(method, action, opts, timeout)
    opts = opts or {}

    action = self.full_prefix .. action
    if opts.query and next(opts.query) then
        action = action .. '?' .. format_params(opts.query)
    end

    local reqData
    if opts.body and next(opts.body) then
        reqData = encode_json(opts.body)
    end

    httpc.timeout = timeout and timeout * 100

	local header = {
		["content-type"] = "application/x-www-form-urlencoded"
	}

    if not self:refresh_jwt_token(timeout and timeout * 100) then
        return false
    end
    header.Authorization = self.jwt_token

    local max_retry = #self.hosts * self.max_fail + 1

    local recvheader = {}
    local stream, error, reqHost
    for i = 1, max_retry, 1 do
        stream, error, reqHost = self:_http_request_stream(method, action, recvheader, header, reqData)
        if stream then
            break
        end

        if error == NONEXIST then
            return false
        end

        if i < max_retry then
            skynet.error("retrying ... ", error)
        end
    end

    local function read_watch()
        if not stream then
            return false
        end
        local success, chunk = xpcall(stream.padding, debug.traceback, stream)
        if not success then
            skynet.error("padding error:%s ",chunk)
            self:_report_failure(reqHost)
            return false
        end

        if not chunk then
            skynet.error("chunk is nil")
            return false
        end

        local data = decode_json(chunk)
        if not data or data.error then
            skynet.error("failed to decode json data: " .. chunk)
            return false
        end

        if data.result and data.result.events then
            for _, event in ipairs(data.result.events) do
                if event.kv.value then   -- DELETE not have value
                    event.kv.value = decode_base64(event.kv.value or "")
                    event.kv.value = decode_json(event.kv.value)
                end
                event.kv.key = decode_base64(event.kv.key)
                if event.prev_kv then
                    event.prev_kv.value = decode_base64(event.prev_kv.value or "")
                    event.prev_kv.value = decode_json(event.prev_kv.value)
                    event.prev_kv.key = decode_base64(event.prev_kv.key)
                end
            end
        end
        return data
    end

    return read_watch, stream
end

function mt:_watch(key, attr)
    if #key == 0 then
        key = str_char(0)
    end

    key = encode_base64(key)

    local range_end
    if attr.range_end then
        range_end = encode_base64(attr.range_end)
    end

    local prev_kv
    if attr.prev_kv then
        prev_kv = attr.prev_kv and true or false
    end

    local start_revision
    if attr.start_revision then
        start_revision = attr.start_revision and attr.start_revision or 0
    end

    local watch_id
    if attr.watch_id then
        watch_id = attr.watch_id and attr.watch_id or 0
    end

    local progress_notify
    if attr.progress_notify then
        progress_notify = attr.progress_notify and true or false
    end

    local fragment
    if attr.fragment then
        fragment = attr.fragment and true or false
    end

    local filters
    if attr.filters then
        filters = attr.filters and attr.filters or 0
    end

    local opts = {
        body = {
            create_request = {
                key             = key,
                range_end       = range_end,
                prev_kv         = prev_kv,
                start_revision  = start_revision,
                watch_id        = watch_id,
                progress_notify = progress_notify,
                fragment        = fragment,
                filters         = filters,
            }
        },
    }

    local endpoint = self:_choose_endpoint()
    if not endpoint then
        skynet.error(NONEXIST)
        return false
    end

    local callback_fun, stream = self:_request_stream('POST', '/watch', opts, attr.timeout or self.timeout)

    return callback_fun, stream
end

--[[
    get value
]]
function mt:get(key, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local attr = {}
    attr.timeout = opts and opts.timeout
    attr.revision = opts and opts.revision

    return self:_get(key, attr)
end

--[[
    watch key
]]
function mt:watch(key, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local attr = {}
    attr.start_revision = opts and opts.start_revision
    attr.timeout = opts and opts.timeout
    attr.progress_notify = opts and opts.progress_notify
    attr.filters = opts and opts.filters
    attr.prev_kv = opts and opts.prev_kv
    attr.watch_id = opts and opts.watch_id
    attr.fragment = opts and opts.fragment

    return self:_watch(key, attr)
end

--[[
    cancel watch key
]]
function mt:watchcancel(stream)
    stream:_onclose()
end

--[[
    read dir
]]
function mt:readdir(key, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local attr = {}
    attr.range_end = get_range_end(key)
    attr.revision = opts and opts.revision
    attr.timeout = opts and opts.timeout
    attr.limit = opts and opts.limit
    attr.sort_order = opts and opts.sort_order
    attr.sort_target = opts and opts.sort_target
    attr.keys_only = opts and opts.keys_only
    attr.count_only = opts and opts.count_only

    return self:_get(key, attr)
end

--[[
    watch dir
]]
function mt:watchdir(key, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local attr = {}

    attr.range_end = get_range_end(key)
    attr.start_revision = opts and opts.start_revision
    attr.timeout = opts and opts.timeout
    attr.progress_notify = opts and opts.progress_notify
    attr.filters = opts and opts.filters
    attr.prev_kv = opts and opts.prev_kv
    attr.watch_id = opts and opts.watch_id
    attr.fragment = opts and opts.fragment

    return self:_watch(key, attr)
end

--[[
    set value
]]
function mt:set(key, val, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local attr = {}
    attr.timeout = opts and opts.timeout
    attr.lease = opts and opts.lease
    attr.prev_kv = opts and opts.prev_kv
    attr.ignore_value = opts and opts.ignore_value
    attr.ignore_lease = opts and opts.ignore_lease

    return self:_set(key, val, attr)
end

--[[
    set key-val if key does not exists (atomic create)
]]
function mt:setnx(key, val, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local compare = {}
    compare[1] = {}
    compare[1].target = "CREATE"
    compare[1].key = encode_base64(key)
    compare[1].createRevision = 0

    local success = {}
    success[1] = {}
    success[1].requestPut = {}
    success[1].requestPut.key = encode_base64(key)

    val = serialize_and_encode_base64(val)
    if not val then
        skynet.error("setnx value invalid")
        return false
    end

    success[1].requestPut.value = val

    return self:_txn(opts, compare, success, nil)
end

--[[
    set key-val and ttl if key is exists (update)
]]
function mt:setx(key, val, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local compare = {}
    compare[1] = {}
    compare[1].target = "CREATE"
    compare[1].key = encode_base64(key)
    compare[1].createRevision = 0

    local failure = {}
    failure[1] = {}
    failure[1].requestPut = {}
    failure[1].requestPut.key = encode_base64(key)

    val = serialize_and_encode_base64(val)
    if not val then
        skynet.error("setx value invalid")
        return false
    end
    failure[1].requestPut.value = val

    return self:_txn(opts, compare, nil, failure)
end

function mt:txn(compare, success, failure, opts)
    if compare then
        local new_rules = tab_clone(compare)
        for i, rule in ipairs(compare) do
            rule = tab_clone(rule)

            rule.key = encode_base64(get_real_key(self.key_prefix, rule.key))

            if rule.value then
                rule.value = serialize_and_encode_base64(rule.value)
                if not rule.value then
                    skynet.error("txn value invalid")
                    return false
                end
            end

            new_rules[i] = rule
        end
        compare = new_rules
    end

    if success then
        local new_rules = tab_clone(success)
        for i, rule in ipairs(success) do
            rule = tab_clone(rule)
            if rule.requestPut then
                local requestPut = tab_clone(rule.requestPut)
                requestPut.key = encode_base64(get_real_key(self.key_prefix, requestPut.key))
                requestPut.value = serialize_and_encode_base64(requestPut.value)
                if not requestPut.value then
                    skynet.error("txn value invalid")
                    return false
                end
                if not requestPut.value then
                    skynet.error("failed to encode value")
                    return false
                end

                rule.requestPut = requestPut
            end
            new_rules[i] = rule
        end
        success = new_rules
    end

    return self:_txn(opts, compare, success, failure)
end

function mt:grant(ttl, id)
    if type(ttl) ~= "number" then
        skynet.error("lease grant command needs TTL argument")
        return false
    end

    if not id then
        skynet.error("lease grant command needs ID argument")
        return false
    end

    id = id or 0
    local opts = {
        body = {
            TTL = ttl,
            ID = id
        },
    }

    return self:_request("POST", "/lease/grant", opts)
end

function mt:revoke(id)
    if not id then
        skynet.error("lease revoke command needs ID argument")
        return false
    end

    local opts = {
        body = {
            ID = id
        },
    }

    return self:_request("POST", "/kv/lease/revoke", opts)
end

function mt:keepalive(id)
    if not id then
        skynet.error("lease keepalive command needs ID argument")
        return false
    end

    local opts = {
        body = {
            ID = id
        },
    }

    return self:_request("POST", "/lease/keepalive", opts)
end

function mt:timetolive(id, keys)
    if not id then
        skynet.error("lease timetolive command needs ID argument")
        return false
    end

    keys = keys or false
    local opts = {
        body = {
            ID = id,
            keys = keys
        },
    }

    local data = self:_request("POST", "/kv/lease/timetolive", opts)

    if data and data.keys and next(data.keys) then
        for i, key in ipairs(data.keys) do
            data.keys[i] = decode_base64(key)
        end
    end

    return data
end

function mt:leases()
    return self:_request("POST", "/lease/leases")
end


--[[
    get version
--]]
function mt:version()
    return self:_request("GET", "/version", nil, self.timeout)
end

--[[
    get stats
--]]
function mt:stats_leader()
    return self:_request("GET", "/v2/stats/leader", nil, self.timeout)
end

function  mt:stats_self()
    return self:_request("GET", "/v2/stats/self", nil, self.timeout)
end

function  mt:stats_store()
    return self:_request("GET", "/v2/stats/store", nil, self.timeout)
end


function mt:delete(key, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local attr = {}
    attr.timeout = opts and opts.timeout
    attr.prev_kv = opts and opts.prev_kv

    return self:_delete(key, attr)
end

function mt:rmdir(key, opts)
    if not verify_key(key) then
        skynet.error("key invalid")
        return false
    end

    key = get_real_key(self.key_prefix, key)

    local attr = {}
    attr.range_end = get_range_end(key)
    attr.timeout = opts and opts.timeout
    attr.prev_kv = opts and opts.prev_kv

    return self:_delete(key, attr)
end

function M.new(opts)
    local hosts = opts.hosts
    local key_prefix = opts.key_prefix
    local timeout = opts.timeout
    local user = opts.user
    local password = opts.password

    if type(hosts) ~= "table" then
        skynet.error("hosts must be table")
        return false
    end

    if key_prefix and type(key_prefix) ~= "string" then
        skynet.error("key_prefix must be string")
        return false
    end

    if not user then
        skynet.error("user error")
        return false
    end

    if not password then
        skynet.error("password error")
        return false
    end

    local obj = {
        full_prefix = "/v3",
        hosts = hosts,
        key_prefix = key_prefix,
        timeout = timeout or 5,
        fail_time = 30,
        max_fail = 2,
        user = user,
        password = password,
        last_auth_time = nil,
        jwt_token = nil,
    }
    return setmetatable(obj, mt)
end

return M