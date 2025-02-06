--[[
  local MyClass = class('MyClass'):include(singleton)

  -- Get the first instance
  local obj1 = MyClass:instance()

  -- Get the second instance, which is the same as the first one
  local obj2 = MyClass:instance()
]]

local singleton = { static = {} }

function singleton:included(class)
    -- Override new to throw an error, but store a reference to the old "new" method
    class.static._new = class.static.new
    class.static.new = function()
        error("Use " .. class.name .. ":instance() instead of :new()")
    end
end

function singleton.static:instance(...)
    self._instance = self._instance or self._new(self, ...) -- use old "new" method
    return self._instance
end

return singleton
