local ss = require "snapshot"
local snapshot = ss.snapshot
local str2ud = ss.str2ud
local ud2str = ss.ud2str
local sformat = string.format
local tconcat = table.concat
local M = {}
local Root = str2ud("0")

local t2simple = {
    table = "(T)",
    userdata = "(U)",
    -- ["function"] = "(L)",
    thread = "(S)",
    cfunction = "(C)",
    string = "(A)",
}

local begin_s = nil
function M.start_snapshot()
    begin_s = snapshot()
end

local function parser_record(s)
    local t, sz = string.match(s, "^([^{}]+) {(%d+)}")
    local parents = {}
    for parent, field in string.gmatch(s, "\n([^%s]+) : ([^\n\0]+)") do
        parents[#parents+1] = {
            parent = str2ud(parent),
            field = field,
        }
    end
    return {
        type = assert(t),
        size = tonumber(assert(sz)),
        parents = parents,
    }
end

local function reshape_snapshot(s, full_snapshot)
    local reshape = {}
    local function add_reshape(k, v, is_new)
        local record = parser_record(v)
        local t = record.type
        local parents = record.parents
        local st = t2simple[t] or sformat("(L@%s)", t)
        reshape[k] = {
            t = t,
            size = record.size,
            st = st,
            parents = parents,
            fullpath = nil,
            addr = k,
            is_new = is_new,
        }

        for _, parent_item in ipairs(parents) do
            local pk = parent_item.parent
            local pv = full_snapshot[pk]
            if not reshape[pk] and pv then
                add_reshape(pk, pv, false)
            end
        end
    end

    for k, v in pairs(s) do
        add_reshape(k, v, true)
    end

    local function concat_path(list, count)
        local len = #list
        count = count or len
        local t = {}
        for i=len, len-count+1, -1 do
            t[#t+1] = list[i]
        end
        return tconcat(t, "->")
    end

    local deep = 0
    local function gen_fullname(addr, list, map)
        list = list or {}
        map  = map or {}
        local entry = reshape[addr]
        local fullpath = entry.fullpath
        if map[addr] then
            return false
        end

        map[addr] = true
        if fullpath then
            list[#list+1] = fullpath
            return true
        end

        local parents = entry.parents
        -- not parent
        if not next(parents) then
            list[#list+1] = "NORoot"
            entry.fullpath = "NORoot"
            return true
        end

        for _, parent_item in ipairs(parents) do
            local pv = parent_item.parent
            local pk = parent_item.field
            -- root parent
            if pv == Root then
                list[#list+1] = entry.st .. pk
                list[#list+1] = "Root"
                entry.fullpath = concat_path(list, 2)
                return true
            end

            -- not find parent
            local parent_entry = reshape[pv]
            if not parent_entry then
                list[#list+1] = pk
                list[#list+1] = sformat("{%s}", ud2str(pv))
                entry.fullpath = concat_path(list, 2)
                return true
            end

            -- is too deep
            if deep >= 64 then
                list[#list+1] = pk
                list[#list+1] = "!PathTooDeep...!"
                entry.fullpath = concat_path(list, 2)
                return true
            end

            local st = entry.st
            local idx = #list+1
            list[idx] = st .. pk
            deep = deep + 1
            local b = gen_fullname(pv, list, map)
            deep = deep - 1
            if b then
                entry.fullpath = concat_path(list, #list-idx+1)
                return true
            else
                assert(#list == idx)
                list[idx] = nil
                map[pv] = nil
            end
        end
        if #parents>0 then
            local pv1 = sformat("{%s}", ud2str(parents[1].parent))
            local pk1 = parents[1].field
            entry.fullpath = concat_path({pk1, pv1})
        else
            entry.fullpath = sformat("{%s}", ud2str(addr))
        end
    end

    for addr, entry in pairs(reshape) do
        gen_fullname(addr)
        assert(entry.fullpath)
    end

    local ret = {}
    for k,v in pairs(reshape) do
        if v.is_new then
            ret[#ret+1] = v
            local parents = v.parents
            for _, parent_item in ipairs(parents) do
                local parent_entry = reshape[parent_item.parent]
                local fullpath = parent_item.parent == Root and "Root" or parent_entry.fullpath
                parent_item.parent_fullpath = assert(fullpath)
                parent_item.parent_st = parent_entry and parent_entry.st or ""
            end
        end
    end
    return ret
end

local function diff_snapshot(begin_s, end_s)
    local reshape
    if not end_s then
        reshape = reshape_snapshot(begin_s, begin_s)
    else
        local diff_s = {}
        for k,v in pairs(end_s) do
            if begin_s[k] == nil then
                diff_s[k] = v
            end
        end
        reshape = reshape_snapshot(diff_s, end_s)
    end
    table.sort(reshape, function (a, b)
            return a.size > b.size
        end)
    return reshape
end

local function dump_reshape(reshape, len)
    local rlen = #reshape
    len = len or rlen
    if len < 0 or len > rlen then
        len = rlen
    end

    local function size_tostring(sz)
        if sz < 1024 * 1024 then
            return sformat("%sKB", sz / 1024)
        elseif sz < 1024 * 1204 * 1024 then
            return sformat("%sMB", sz / 1024 / 1024)
        else
            return sformat("%sGB", sz / 1024 / 1024 / 1024)
        end
    end

    local function path_tostring(st, parent)
        local fullpath = parent.parent_fullpath
        local field = parent.field
        return fullpath .. "->" .. st .. field
    end

    local function entry_tostring(idx, entry)
        local t = {}
        t[1] = sformat("[%d] type:%s addr:%s size:%s",
            idx, entry.st, ud2str(entry.addr), size_tostring(entry.size))

        local len = #entry.parents
        for i=1,len do
            if i >= 8 then
                t[i+1] = sformat("\tparents more than %d ...", len-i)
                break
            end
            t[i+1] = sformat("\t%s", path_tostring(entry.st, entry.parents[i]))
        end
        return tconcat(t, "\n")
    end

    local all_size = 0
    print("------------------ diff snapshot ------------------")
    for i=1, rlen do
        local v = reshape[i]
        all_size = all_size + v.size
        if i <= len then
            print(entry_tostring(i, v))
        elseif i == len+1 then
            print(sformat("more than %d ...", rlen - len))
        end
    end
    print(sformat("--------------- all size:%sKb ---------------", all_size / 1024))
end

function M.dump_snapshot(len, max_objcount)
    local end_s = snapshot(max_objcount)
    local reshape = diff_snapshot(end_s)
    dump_reshape(reshape, len)
end

function M.dstop_snapshot(len)
    if not begin_s then
        error("snapshot not begin")
    end
    for k, _ in pairs(begin_s) do
        begin_s[k] = true -- 释放value，end_s中将不会有这些key
    end
    begin_s[ss.obj2addr(begin_s)] = true -- 消除begin_s的影响
    local end_s = snapshot()
    local reshape = diff_snapshot(begin_s, end_s)
    dump_reshape(reshape, len)
    begin_s = nil
end

return M
