local skynet = require "skynet"
-- 处理 连续多个服务调用时完全独立的，不必等到service1 返回后才调用service2 ... 操作

local M = {}

local mt = {
    __index = M,
}

local function new()
    return setmetatable({
        list = {},
        _bootCo = nil,
        _bootError = nil,
    }, mt)
end

-- 打印异常
local function exception(e)
    skynet.error(e)
    return e
end

function M:wakeup_waitco(err)
    if not self._bootError then
        self._bootError = err
    end
    local bootCo = self._bootCo
    if bootCo then
        self._bootCo = nil
        -- 唤醒一个被 skynet.sleep 或 skynet.wait 挂起的 coroutine
        skynet.wakeup(bootCo)
    end
end

function M:add(func, ...)
    local token = {}
    local list = self.list
    list[token] = true
    -- skynet.fork(func, ...) 从功能上，它等价于 skynet.timeout(0, function() func(...) end)
    -- 但是比 timeout 高效一点。因为它并不需要向框架注册一个定时器
    skynet.fork(function(...)
        token.co = coroutine.running()
        local ok, err = xpcall(func, exception, ...)
        if not ok then
            self:wakeup_waitco(err)
        else
            list[token] = nil
            if not next(list) then
                self:wakeup_waitco()
            end
        end
    end, ...)
end

function M:wait()
    assert(not self._bootCo, string.format("already in wait %s", tostring(self._bootCo)))
    self._bootCo = coroutine.running()
    if not next(self.list) then
        -- skynet.yield() 相当于 skynet.sleep(0) 交出当前服务对 CPU 的控制权
        -- 通常在你想做大量的操作，又没有机会调用阻塞 API 时，可以选择调用 yield 让系统跑的更平滑
        skynet.yield()
    else
        -- 把当前 coroutine 挂起，之后由 skynet.wakeup 唤醒。token 必须是唯一的，默认为 coroutine.running()
        skynet.wait(self._bootCo)
    end
    if self._bootError then
        error(self._bootError)
    end
end

function M:foreach(tb, func, ...)
    for key, item in pairs(tb) do
        self:add(func, key, item, ...)
    end
    self:wait()
end

return new
