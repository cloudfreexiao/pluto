--
-- Based on https://github.com/wscherphof/lua-events/
--

local function tfind(tab, el)
  for index, value in pairs(tab) do
    if value == el then
      return index
    end
  end
end


---@class EventEmitter @EventEmitter
---@field instance fun(...):EventEmitter
local EventEmitter = class("EventEmitter"):include(singleton)

function EventEmitter:initialize()
  self._on = {}
  self._once = {}
end

---@function on
---@param event string
---@param listener function
---@return function
function EventEmitter:on(event, listener)
  self._on[event] = self._on[event] or {}
  table.insert(self._on[event], listener)
  return listener
end

---@function once
---@param event string
---@param listener function
---@return function
function EventEmitter:once(event, listener)
  self._once[event] = listener
  return self:on(event, listener)
end

---@function off
---@param event nil|string
---@param listener nil|function
function EventEmitter:off(event, listener)
  if event then
    -- clear from "once"
    self._once[event] = nil
    if not listener then
      table.remove(self._on[event])
    else
      table.remove(self._on[event], tfind(self._on[event], listener))
    end
  else
    for et in pairs(self._on) do
      self:off(et)
    end
  end
end

---@function listeners
---@param event string
function EventEmitter:listeners(event)
  return self._on[event] or {}
end

function EventEmitter:emit(event, ...)
  -- copy list before iterating over it
  -- (make sure all previously registered callbacks are called, even if some are removed in-between)
  local listeners = {}
  for i, listener in ipairs(self:listeners(event)) do
    listeners[i] = listener
  end

  for _, listener in ipairs(listeners) do
    if "function" == type(listener) then
      -- TODO: xpcall
      listener(...)

      -- clear from "once"
      if self._once[event] == listener then
        self:off(event, listener)
      end
    end
  end
end

return EventEmitter
