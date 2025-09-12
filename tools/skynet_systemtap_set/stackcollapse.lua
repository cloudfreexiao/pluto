local function loadlog(filename)
    local fh = assert(io.open(filename))
    for line in fh:lines() do
        coroutine.yield(line)
    end
    fh:close()
end

local function accumulate(filename)
    local n = 0
    local ret = {}
    for line in coroutine.wrap(function() loadlog(filename) end) do
        local key = string.sub(line, 1, #line - 1)
        ret[line] = (ret[line] or 0) + 1
        n = n + 1
        if n % 100000 then
            collectgarbage "collect"
        end
    end
    return ret
end

local tbl = accumulate("a.bt")
for k, v in pairs(tbl) do
    print(k, v)
end
