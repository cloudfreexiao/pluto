local parser = require "parser"
-- local print_r = require "print_r"

local function append(ret, name, location, end_location)
    ret[#ret+1] = {
        name = name,
        range = {location.line, end_location.line},
    }
end


local function dump_local_function (root, ret)
    assert(root.tag == "Localrec")
    local location = root.location
    local end_location = root[2].end_location
    local name = root[1][1]
    append(ret, name, location, end_location)
end

local function dump_index(root)
    -- print("------------")
    -- print_r(root)
    if root.tag == "Id" then
        return root[1]
    end
    assert(root.tag == "Index")
    local ret = {}
    for i,v in ipairs(root) do
        local tag = v.tag
        if tag == "Id" or tag == "String" then
            ret[#ret+1] = v[1]
        elseif tag == "Index" then
            ret[#ret+1] = dump_index(v)
        end
    end
    return table.concat(ret, ".")
end


local function dump_set_function(root, ret)
    assert(root.tag == "Set")
    assert(root.first_token == "function")
    -- print("$$$$$$$$$")
    -- print_r(root)
    local name = dump_index(root[1][1])
    local location = root[2][1].location
    local end_location = root[2][1].end_location
    append(ret, name, location, end_location)
end


-- 只遍历最外层的function
local function dump_block(root, ret)
    ret = ret or {}
    assert(root.tag == "Block")
    for i,v in ipairs(root) do
        local tag = v.tag
        if tag == "Set" and v.first_token == "function" then
            dump_set_function(v, ret)
        elseif tag == "Localrec" then
            dump_local_function(v, ret)
        end
    end
    return ret
end

local function read_file(path)
    local fd =io.open(path, "r")
    assert(fd, 'not found:'..path)
    local s = fd:read("a")
    fd:close()
    return s
end

local function read_file_in_lines(path)
    local fd = io.open(path, "r")
    assert(fd, path)
    local s = {}
    for line in fd:lines() do
        table.insert(s, line)
    end
    fd:close()
    return s
end

local function gen_lineno_quick_tbl(info)
    local ret = {}
    for _, v in ipairs(info) do
        local name = v.name
        local range = v.range
        local start = range[1]
        local finish = range[2]
        for i=start,finish do
            ret[i] = name
        end
    end
    return ret
end

local function join_path(...)
    local seperator = "/"
    return table.concat({...}, seperator)
end

local source_path, bt_filename = ...

local function extract_source_filename(path)
    local lines = read_file_in_lines(path)
    local filename_map = {}
    for _,line in ipairs(lines) do
        for debug_info in line:gmatch("([_%w%/:%d .]+);") do
            for filename in debug_info:gmatch("([%w.%/_]+):%d+") do
                filename_map[filename] = true
            end
        end
    end
    return filename_map
end

local all_filename = extract_source_filename(bt_filename)

local quick_tbl = {}
for filename in pairs(all_filename) do
    local path = join_path(source_path, filename)
    local source = read_file(path)
    local ast = parser(source)
    local info = dump_block(ast, {})
    quick_tbl[filename] = gen_lineno_quick_tbl(info)
end
--------------------
--search symbol
local flamegraph = read_file_in_lines(bt_filename)
for _,line in ipairs(flamegraph) do
    local newline = {}
    local count = line:match("(%d+)$")
	for debug_info in line:gmatch("([%w%/:%d._]+);") do
		local new_debug_info = string.gsub(debug_info, "([%w%/._]+):(%d+)",function(filename, lineno)
            lineno = tonumber(lineno)
		    local symbol = assert(quick_tbl[filename], filename)
			local funcname = symbol[lineno] or debug_info
            return table.concat({filename, ':', funcname})
		end)
        table.insert(newline, new_debug_info)
	end
    print(table.concat(newline, ';').." "..count)
end
