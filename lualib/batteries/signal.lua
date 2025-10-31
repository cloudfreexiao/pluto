-- https://github.com/uzkbwza/signal.lua

---@class Signal
---@field emitters table<table, table<string|number, {listeners: table<table, table<string|number, {func: function, oneshot: boolean}>>}>>
---@field listeners table<table, table<table, table<string|number, table<string|number, {func: function, oneshot: boolean}>>>>>
local signal = {
    emitters = {},
    listeners = {},
}

---@param t table
---@return boolean
local function is_empty(t)
    return next(t) == nil
end

---@param emitter table
---@param id string | number
function signal.register(emitter, id)
    signal.emitters[emitter] = signal.emitters[emitter] or {}
    assert(signal.emitters[emitter][id] == nil, "signal already registered")
    signal.emitters[emitter][id] = {
        listeners = {}
    }
end

---@param emitter table
---@param id string | number
---@return table?
function signal.get(emitter, id)
    if signal.emitters[emitter] == nil then return nil end
    return signal.emitters[emitter][id]
end

---@param emitter table
---@param id string | number
function signal.deregister(emitter, id)
    local sig = signal.get(emitter, id)

    if sig == nil then return end

    for listener, connection in pairs(sig) do
        for connection_name, _ in pairs(connection) do
            signal.disconnect(emitter, id, listener, connection_name)
        end
    end

    signal.emitters[emitter][id] = nil
    if is_empty(signal.emitters[emitter]) then signal.emitters[emitter] = nil end
end

---@param obj table
function signal.cleanup(obj)
    assert(type(obj) == "table", "obj is not a table")
    local lis = signal.listeners[obj]
    if lis ~= nil then
        for emitter, signals in pairs(lis) do
            for signal_name, functions in pairs(signals) do
                for connection_name, _ in pairs(functions) do
                    signal.disconnect(emitter, signal_name, obj, connection_name)
                end
            end
        end
    end

    local signals = signal.emitters[obj]

    if signals ~= nil then
        for signal_name, t in pairs(signals) do
            for listener, connection in pairs(t.listeners) do
                for connection_name, _ in pairs(connection) do
                    signal.disconnect(obj, signal_name, listener, connection_name)
                end
            end
        end
    end

    signal.emitters[obj] = nil
end

---@param emitter table
---@param signal_id string | number
---@param listener table
---@param connection_id string | number
---@param func? function
---@param oneshot? boolean
function signal.connect(emitter, signal_id, listener, connection_id, func, oneshot)
    assert(type(emitter) == "table", "emitter is not a table")
    assert(type(listener) == "table", "listener is not a table")
    local signal_id_type = type(signal_id)
    local connection_id_type = type(connection_id)
    assert(signal_id_type == "string" or signal_id_type == "number", "signal_id is not a string or number")
    assert(connection_id_type == "string" or connection_id_type == "number", "connection_id is not a string or number")

    assert(emitter ~= nil, "emitter is nil")
    assert(listener ~= nil, "listener is nil")

    if oneshot == nil then oneshot = false end

    local sig = signal.get(emitter, signal_id)

    if sig == nil then
        error("signal " .. tostring(signal_id) .. " does not exist for object " .. tostring(emitter))
    end

    sig.listeners[listener] = sig.listeners[listener] or {}

    -- if a function is not provided, use the connection_id as a function
    func = func or function(...) listener[connection_id](listener, ...) end

    sig.listeners[listener][connection_id] = {
        func = func,
        oneshot = oneshot,
    }

    signal.listeners[listener] = signal.listeners[listener] or {}
    signal.listeners[listener][emitter] = signal.listeners[listener][emitter] or {}
    signal.listeners[listener][emitter][signal_id] = signal.listeners[listener][emitter][signal_id] or {}
    local lis = signal.listeners[listener][emitter][signal_id]

    assert(lis[connection_id] == nil, "connection already exists!")

    lis[connection_id] = {
        func = func,
        oneshot = oneshot,
    }
end

---@param emitter table
---@param signal_id string | number
---@param listener table
---@param connection_id string | number
function signal.disconnect(emitter, signal_id, listener, connection_id)
    assert(type(emitter) == "table", "emitter is not a table")
    assert(type(listener) == "table", "listener is not a table")
    local signal_id_type = type(signal_id)
    local connection_id_type = type(connection_id)
    assert(signal_id_type == "string" or signal_id_type == "number", "signal_id is not a string or number")
    assert(connection_id_type == "string" or connection_id_type == "number", "connection_id is not a string or number")

    local sig = signal.get(emitter, signal_id)
    if (sig == nil) then error("signal " .. tostring(signal_id) .. " does not exist for object " .. tostring(emitter)) end

    if sig.listeners[listener] ~= nil then
        sig.listeners[listener][connection_id] = nil

        if is_empty(sig.listeners[listener]) then
            sig.listeners[listener] = nil
        end
    end

    local lis = signal.listeners[listener]

    if lis[emitter] ~= nil then
        if lis[emitter][signal_id] ~= nil then
            lis[emitter][signal_id][connection_id] = nil
            if is_empty(lis[emitter][signal_id]) then
                lis[emitter][signal_id] = nil
            end
        end
        if is_empty(lis[emitter]) then
            signal.listeners[listener][emitter] = nil
        end
    end

    if is_empty(lis) then
        signal.listeners[listener] = nil
    end
end

---@param emitter table
---@param signal_id string | number
---@param ... any
function signal.emit(emitter, signal_id, ...)
    local sig = signal.get(emitter, signal_id)
    if sig == nil then error("no signal " .. tostring(signal_id) .. " for emitter " .. tostring(emitter)) end
    for listener, connection in pairs(sig.listeners) do
        for func_name, t in pairs(connection) do
            local func = t.func
            func(...)
            if t.oneshot then
                signal.disconnect(emitter, signal_id, listener, func_name)
            end
        end
    end
end

---@type Signal
return signal
