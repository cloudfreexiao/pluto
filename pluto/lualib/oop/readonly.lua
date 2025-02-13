---@diagnostic disable: need-check-nil
local SetReadonly = nil

local meta = {
    __index = function(self, k)
        return SetReadonly(self.__src[k])
    end,
    __newindex = function(self, k, v)
        error(("SetReadonly error %s %s"):format(k, v), 2)
    end,
    __pairs = function(self)
        return next, self
    end,
    __len = function(self)
        return #self.__src
    end,
    __next = function(self, k)
        local nk, nv = next(self.__src, k)
        return nk, SetReadonly(nv)
    end,
}

SetReadonly = function(src)
    if type(src) ~= "table" then
        return src
    end

    return setmetatable({
        __src = src,
    }, meta)
end

local GetReadonly = function(src)
    return src and src.__src
end

return {
    set = SetReadonly,
    get = GetReadonly,
}
