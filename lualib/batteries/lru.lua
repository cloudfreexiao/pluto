local string = string
local tostring = tostring
local table = table

---@class LruNode 链表节点
---@field key any 节点值
---@field value any 节点值
---@field first LruNode 前一个指针
---@field pre LruNode? 前一个指针
---@field next LruNode 后一个指针
local function LruNode(key, value, pre, next)
    return {
        key = key,
        value = value,
        pre = pre,
        next = next,
    }
end

---@class Lru @LRU算法
---@field _nodes table<any, LruNode> 节点
---@field _tail LruNode 尾节点
---@field _head LruNode 头节点
---@field _len number 长度
---@field _max number 容量上限
---@field _fremove function 删除后的回调
local Lru = {}

--- 创建一个lru
---@param max number 容量上限
function Lru.new(max)
    assert(max > 0)

    local self = {}
    self._max = max
    self._nodes = {}
    self._head = LruNode()
    self._tail = LruNode()
    self._len = 0

    ---@type function @删除后的回调
    self._fremove = nil

    -- 类似stl的方式，头尾只是作为指针使用
    self._head.next = self._tail
    self._tail.first = self._head

    return setmetatable(self, {
        __index = Lru,
        __len = function(self)
            return self._len
        end,
        __tostring = function(self)
            local ret = {}
            local next = self._head.next
            while next and next ~= self._tail do
                ret[#ret + 1] = string.format("(%s,%s)", next.key, tostring(next.value))
                next = next.next
            end

            return table.concat(ret, ',')
        end,
        __pairs = function()
            local next_key, next_val
            return function()
                if next_key then
                    next_key, next_val = self._nodes[next_key].next.key, self._nodes[next_key].next.value
                else
                    next_key, next_val = self._head.next.key, self._head.next.value
                end
                return next_key, next_val
            end
        end,
    })
end

--- 设置上限
---@param max number 上限
function Lru:max(max)
    if max > 0 then
        self._max = max
        self:_cut()
    end
end

--- 获取上限
function Lru:getMax()
    return self._max
end

--- 设置删除的回调函数
---@param func function 回调函数
function Lru:fremove(func)
    self._fremove = func
end

--- 值是否存在
---@param key any 键
---@return boolean 是否存在
function Lru:exist(key)
    local node = self._nodes[key]
    return node ~= nil
end

--- 查值,不会置顶
---@param key any 键
---@return any 值
function Lru:query(key)
    local node = self._nodes[key]
    if node then
        return node.value
    end
end

--- 取值,会置顶
---@param key any 键
---@return any 值
function Lru:get(key)
    local node = self._nodes[key]
    if node then
        self:_top(node)
        return node.value
    end
end

--- 改变值
---@param key any 键
---@param value any 值
---@param force boolean? 强制上限加一
function Lru:set(key, value, force)
    if force then
        self._max = self._max + 1
    end

    local node = self._nodes[key]
    if node then
        node.value = value
        self:_top(node)
    else
        self:_newtop(key, value)
    end
end

--- 删除值
---@param key any 键
function Lru:remove(key)
    local node = self._nodes[key]
    if node then
        self:_remove(node)
        self:_onremove({ node })
        return node.value
    end
end

--- 销毁值
-- destroy不会触发remove的回调!
---@param key any 键
function Lru:destroy(key)
    local node = self._nodes[key]
    if node then
        self:_remove(node)
    end
end

--- 置顶
---@param node any
function Lru:_top(node)
    local next = self._head.next
    if next ~= node then
        self:_remove(node)
        self:_newtop(node.key, node.value)
    end
end

--- 添加一个新的节点到头
---@param key string 键
---@param value any 值
function Lru:_newtop(key, value)
    local head = self._head
    local next = head.next
    local new = LruNode(key, value, head, next)
    head.next = new
    next.pre = new
    self._nodes[key] = new
    self._len = self._len + 1
    self:_cut()
end

--- 根据上限裁剪超出的节点
function Lru:_cut()
    local nodes = {}
    while self._len > self._max do
        local node = self._tail.pre
        if node then
            table.insert(nodes, node)
            self:_remove(node)
        end
    end
    self:_onremove(nodes)
end

--- 执行删除的回调
---@param nodes table LruNode数组
function Lru:_onremove(nodes)
    local func = self._fremove
    if not func then
        return
    end

    for _, node in ipairs(nodes) do
        func(node.key, node.value)
    end
end

--- 删除一个节点
---@param node LruNode 要删除的节点
function Lru:_remove(node)
    local pre = node.pre
    local next = node.next

    if pre == nil then
        self._head = next
    else
        pre.next = next
    end

    if next ~= nil then
        next.pre = pre
    end

    self._nodes[node.key] = nil
    self._len = self._len - 1

    return node
end

return Lru
