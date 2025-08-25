-- 在 Skynet 环境里模拟 OpenResty cosocket API
local skynet = require("skynet")
local socket = require("skynet.socket")
local coroutine = coroutine
local tostring = tostring

local socket_error = setmetatable({}, {
    __tostring = function(self)
        local info = self.err_info
        self.err_info = nil
        return info or "[Socket Error]"
    end,

    __call = function(self, info)
        self.err_info = "[Socket Error] : " .. tostring(info)
        return self
    end
})


local _M = {}
_M.__index = _M

-- 创建 TCP socket 对象
function _M.tcp()
    local self = {
        id = nil,
        timeout = nil,
    }
    return setmetatable(self, _M)
end

-- 设置超时（秒）
function _M:settimeout(sec)
    self.timeout = sec * 100
end

-- 连接远程
function _M:connect(host, port)
    local fd, err
    local is_time_out = false

    if self.timeout then
        is_time_out = true
        local drop_fd
        local co = coroutine.running()
        -- asynchronous connect
        skynet.fork(function()
            fd, err = socket.open(host, port)
            if drop_fd then
                -- sockethelper.connect already return, and raise socket_error
                socket.close(fd)
            else
                -- socket.open before sleep, wakeup.
                is_time_out = false
                skynet.wakeup(co)
            end
        end)
        skynet.sleep(self.timeout)
        if not fd then
            -- not connect yet
            drop_fd = true
        end
    else
        is_time_out = false
        -- block connect
        fd, err = socket.open(host, port)
    end

    assert(self.id, socket_error("connect failed host = " ..
        host ..
        ' port = ' ..
        port ..
        ' timeout = ' ..
        tostring(self.timeout) .. ' err = ' .. tostring(err) .. ' is_time_out = ' .. tostring(is_time_out)))

    self.id = fd
end

-- 发送数据
function _M:send(data)
    if not self.id then
        return nil, "not connected"
    end
    local ok, err = pcall(socket.write, self.id, data)
    if not ok then
        return nil, err
    end
    return ok
end

-- 接收数据
-- size: 数字 / "*l" / "*a"
function _M:receive(size)
    if not self.id then
        return nil, "not connected"
    end

    local data
    if type(size) == "number" then
        data = socket.read(self.id, size)
    else
        assert(false, "invalid receive size", size)
    end
    return data
end

-- 关闭连接
function _M:close()
    if self.id then
        socket.close(self.id)
        self.id = nil
    end
end

return _M
