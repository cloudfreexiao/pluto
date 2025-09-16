-- https://github.com/Tieske/mediator2

--- Mediator pattern implementation for Lua.
-- mediator2 allows you to subscribe and publish to a central object so
-- you can decouple function calls in your application. It's as simple as:
--
--     mediator:addSubscriber({"channel"}, function)
--
-- Supports namespacing, predicates, wildcards,
-- and more.
--
-- __Some basics__:
--
-- *Priorities*
--
-- Subscribers can have priorities. The lower the number, the higher the priority.
-- The default priority is after all existing handlers.
-- The priorities are implemented as array-indices, so they are 1-based (highest).
-- This also means that changing priority of a subscriber might impact the absolute value
-- of the priority of other subscribers.
--
-- *Channels*
--
-- Channels have a tree structure, where each channel can have multiple sub-channels.
-- When publishing to a channel, the parent channel will be published to as well.
-- Channels are automatically created when subscribing or publishing to them.
-- Technically the channel is implemented as an array of namespaces, for example:
-- `{"car", "engine", "rpm"}`
--
-- *Context*
--
-- Subscribers can have a context. The context is a value that will be passed to the subscriber
-- on each call. The context will be omitted from the callback if not provided (`nil`). It can be
-- any valid Lua value, and usually is a table.
-- The context doubles as a `self` parameter for object-based handlers.
--
-- *Predicates*
--
-- Subscribers can have predicates. A predicate is a function that returns a boolean.
-- If the predicate returns `true`, the subscriber will be called.
-- The predicate function will be passed the ctx (if present) + the arguments that were
-- passed to the publish function.
--
-- *Callback results*
--
-- Subscriber callback functions can return 2 values:
--
-- 1. A signal to the mediator to stop or continue calling the next subscriber.
-- Should be `mediator.CONTINUE` (default) or `mediator.STOP`.
-- 2. Any value to be stored in the result table and passed back to the publisher.
--
-- @module mediator
-- @release 2.0.0
-- @license MIT
-- @copyright Copyright (c) 2012-2020 Olivine Labs, 2024-2025 Thijs Schreijer


-- signals to be returned by the subscriber to tell the mediator to stop or continue
local STOP = {}
local CONTINUE = {}
local WILDCARD = {}

local Mediator = {
}


--- Subscriber class.
-- This class is instantiated by the `mediator:addSubscriber` and `Channel:addSubscriber` methods.
-- @type Subscriber
-- @usage
-- local m = require("mediator")()
-- local sub1 = m:addSubscriber({"car", "engine", "rpm"}, function(value, unit)
--     print("Sub1 ", value, unit)
--   end)
-- local sub2 = m:addSubscriber({"car", "engine", "rpm"}, function(value, unit)
--     print("Sub2 ", value, unit)
--   end)
--
-- m:publish({"car", "engine", "rpm"}, 1000, "rpm")
-- -- Output:
-- -- Sub1 1000 rpm
-- -- Sub2 1000 rpm
--
-- sub2:setPriority(1)
--
-- m:publish({"car", "engine", "rpm"}, 2000, "rpm")
-- -- Output:
-- -- Sub2 2000 rpm
-- -- Sub1 2000 rpm
--
-- sub1:remove()
--
-- m:publish({"car", "engine", "rpm"}, 3000, "rpm")
-- -- Output:
-- -- Sub2 3000 rpm
--
-- local options = {
--   ctx = { count = 0 },       -- if provided, will be passed on each call
--   predicate = nil,
--   priority = 1,              -- make this one the top-priority
-- }
-- local sub3 = m:addSubscriber({"car", "engine", "rpm"}, function(ctx, value, unit)
--     ctx.count = ctx.count + 1
--     print("Sub3 ", ctx.count, value, unit)
--     return m.STOP, count     -- stop the mediator from calling the next subscriber
--   end)
--
-- local results = m:publish({"car", "engine", "rpm"}, 1000, "rpm")
-- -- Output:
-- -- Sub3 1 1000 rpm
--
-- print(results[1]) -- 1      -- the result, count, returned from subscriber sub3

local Subscriber = setmetatable({},{

  -- Instantiates a new Subscriber object.
  -- @tparam function fn The callback function to be called when the channel is published to.
  -- @tparam table options A table of options for the subscriber, see `mediator:addSubscriber` for fields.
  -- @tparam Channel channel The channel the subscriber is subscribed to.
  -- @treturn Subscriber the newly created subscriber
  __call = function(self, fn, options, channel)
    return setmetatable({
        options = options or {},
        fn = fn,
        channel = channel,
      }, self)
  end
})

function Subscriber:__index(key)
  local val = Subscriber[key]
  self[key] = val -- copy method to instance for faster future access
  return val
end



--- Updates the subscriber with new options.
-- @tparam table updates A table of updates options for the subscriber, with fields:
-- @tparam[opt] function updates.fn The new callback function to be called when the channel is published to.
-- @tparam[opt] table updates.options The new options for the subscriber, see `mediator:addSubscriber` for fields.
-- @return nothing
function Subscriber:update(updates)
  if updates then
    self.fn = updates.fn or self.fn
    self.options = updates.options or self.options
    if self.options.priority then
      self:setPriority(self.options.priority)
      self.options.priority = nil
    end
  end
end



--- Changes the priority of the subscriber.
-- @tparam number priority The new priority of the subscriber.
-- @return the priority as set
function Subscriber:setPriority(priority)
  return self.channel:_setPriority(self, priority)
end



--- Removes the subscriber.
-- @return the removed `Subscriber`
function Subscriber:remove()
  local channel = self.channel
  self.channel = nil
  return channel:_removeSubscriber(self)
end



--- Channel class.
-- This class is instantiated automatically by accessing channels (passing the namespace-array) to the
-- `mediator` methods. To create or access one use `mediator:getChannel`.
-- @type Channel
local Channel = setmetatable({}, {

  -- Instantiates a new Channel object.
  -- @tparam string namespace The namespace of the channel.
  -- @tparam Channel parent The parent channel.
  -- @tparam Mediator mediator The mediator object the channel belongs to.
  -- @treturn Channel the newly created channel
  __call = function(self, namespace, parent, mediator)
    assert(mediator or parent, "Mediator or parent channel required")
    local chan = {
      namespace = namespace,
      fullNamespace = { namespace }, -- the full list of namespaces, including parents
      subscribers = {},
      channels = {},
      parent = parent,
      mediator = mediator or parent.mediator,
    }

    -- copy the full namespace list from the parent-tree
    local p = parent
    while p do
      if p.parent ~= nil then
        table.insert(chan.fullNamespace, 1, p.namespace)
      end
      p = p.parent
    end

    return setmetatable(chan, self)
  end
})

function Channel:__index(key)
  local val = Channel[key]
  self[key] = val -- copy method to instance for faster future access
  return val
end



--- Creates a subscriber and adds it to the channel.
-- @tparam function fn The callback function to be called when the channel is published to.
-- @tparam table options A table of options for the subscriber. See `mediator:subscribe` for fields.
-- @treturn Subscriber the newly created subscriber
function Channel:addSubscriber(fn, options)
  options = options or {}

  local priority = options.priority or (#self.subscribers + 1)
  priority = math.max(math.min(math.floor(priority), #self.subscribers + 1), 1)
  options.priority = nil

  local callback = Subscriber(fn, options, self)

  table.insert(self.subscribers, priority, callback)

  return callback
end



-- Sets the priority of a subscriber.
-- @tparam number id The id of the subscriber to set the priority of.
-- @tparam number priority The new priority of the subscriber.
-- @return the priority set
function Channel:_setPriority(subscriber, priority)
  priority = math.max(math.min(math.floor(priority), #self.subscribers), 1)

  local index
  for i, callback in ipairs(self.subscribers) do
    if callback == subscriber then
      index = i
      break
    end
  end

  if not index then
    error("Subscriber not found") -- this is an internal error, should never happen
  end

  table.remove(self.subscribers, index)
  table.insert(self.subscribers, priority, subscriber)
  return priority
end



--- Adds a single namespace/sub-channel to the current channel.
-- If the channel already exists, the existing one will be returned.
-- @tparam string namespace The namespace of the channel to add.
-- @treturn Channel the newly created channel
function Channel:addChannel(namespace)
  self.channels[namespace] = self.channels[namespace] or Channel(namespace, self)
  return self.channels[namespace]
end



--- Checks if a single namespace/sub-channel exists within the current channel.
-- @tparam string namespace The namespace of the channel to check.
-- @treturn boolean `true` if the channel exists, `false` otherwise
function Channel:hasChannel(namespace)
  return namespace and self.channels[namespace] and true
end



--- Gets a single namespace/sub-channel from the current channel, or creates it if it doesn't exist.
-- @tparam string namespace The namespace of the channel to get.
-- @treturn Channel the existing, or newly created channel
function Channel:getChannel(namespace)
  return self.channels[namespace] or self:addChannel(namespace)
end



--- Gets the full namespace array for the current channel.
-- @treturn Array the full namespace array
function Channel:getNamespaces()
  return self.fullNamespace
end



-- Removes a subscriber.
-- @tparam number id The id of the subscriber to remove.
-- @treturn Subscriber the removed subscriber
function Channel:_removeSubscriber(subscriber)
  for i, callback in ipairs(self.subscribers) do
    if subscriber == callback then
      table.remove(self.subscribers, i)
      return subscriber
    end
  end
  -- TODO: add test for this error
  error("Subscriber not found")
end



-- Publishes to this channel.
-- @tparam table results Return values (first only) from the callbacks will be stored in this table
-- @tparam boolean isChildEvent Is this a child event for this channel?
-- @param ... The arguments to pass to the subscribers.
-- @treturn table The result table after all subscribers have been called.
-- @treturn signal Either `mediator.STOP`, or `mediator.CONTINUE`
function Channel:_publish(results, isChildEvent, ...)
  for i, subscriber in ipairs(self.subscribers) do
    local ctx = subscriber.options.ctx
    local predicate = subscriber.options.predicate
    local skipChildren = subscriber.options.skipChildren
    local shouldRun = true

    if isChildEvent and skipChildren then
      shouldRun = false
    end

    if shouldRun and predicate then
      if ctx ~= nil then
        shouldRun = predicate(ctx, ...)
      else
        shouldRun = predicate(...)
      end
    end

    if shouldRun then
      local continue, result
      if ctx ~= nil then
        continue, result = subscriber.fn(ctx, ...)
      else
        continue, result = subscriber.fn(...)
      end
      results[#results+1] = result

      if (continue == nil) and (result == nil) then
        continue = CONTINUE
      end

      if continue ~= CONTINUE then
        if continue == STOP then
          return results, STOP
        else
          local info = debug.getinfo(subscriber.fn)
          local err = ("Invalid return value from subscriber%s:%s, expected mediator.STOP or mediator.CONTINUE"):format(info.source, info.linedefined)
          error(err)
        end
      end
    end
  end

  return results, CONTINUE
end



-- Publishes to this channel.
-- @param ... The arguments to pass to the subscribers.
-- @treturn table The result table after all subscribers have been called.
function Channel:publish(...)
  return self.mediator:publish(self.fullNamespace, ...)
end



--- Mediator class.
-- This class is instantiated by calling on the module table.
-- @type Mediator

Mediator = setmetatable(Mediator,{
  __call = function(self)
    local med = {}
    med.channel = Channel('root', nil, med)
    return setmetatable(med, self)
  end
})

function Mediator:__index(key)
  local val = Mediator[key]
  self[key] = val -- copy method to instance for faster future access
  return val
end



--- Gets a channel by its namespaces, or creates them if they don't exist.
-- @tparam array channelNamespaces The namespace-array of the channel to get.
-- @treturn Channel the existing, or newly created channel
-- @usage
-- local m = require("mediator")()
-- local channel = m:getChannel({"car", "engine", "rpm"})
function Mediator:getChannel(channelNamespaces)
  local channel = self.channel

  for _, namespace in ipairs(channelNamespaces) do
    channel = channel:getChannel(namespace)
  end

  return channel
end



--- Subscribes to a channel.
-- @tparam array channelNamespaces The namespace-array of the channel to subscribe to (created if it doesn't exist).
-- @tparam function fn The callback function to be called when the channel is published to.
-- signature: <br/>`continueSignal, result = fn([ctx,] ...)`<br/> where `result` is any value to be stored in the result
-- table and passed back to the publisher. `continueSignal` is a signal to the mediator to stop or continue
-- calling the next subscriber, should be `mediator.STOP` or `mediator.CONTINUE` (default).
-- @tparam table options A table of options for the subscriber, with fields:
-- @tparam[opt] any options.ctx The context to call the subscriber with, will be omitted from the callback if `nil`.
-- @tparam[opt] function options.predicate A function that returns a boolean. If `true`, the subscriber will be called.
-- The predicate function will be passed the ctx + the arguments that were passed to the publish function.
-- @tparam[opt] integer options.priority The priority of the subscriber. The lower the number,
-- the higher the priority. Defaults to after all existing handlers.
-- @tparam[opt] boolean options.skipChildren If `true`, the subscriber will only be invoked on direct
-- publishes to this channel, but not for any child channels.
-- @treturn Subscriber the newly created subscriber
function Mediator:addSubscriber(channelNamespaces, fn, options)
  return self:getChannel(channelNamespaces):addSubscriber(fn, options)
end



do
  local function recursive_publish(channelNamespaces, current_idx, current_channel, result, ...)
    if current_idx == #channelNamespaces then
      -- this is the target channel
      return current_channel:_publish(result, false, ...)
    end

    -- first publish to the matching subchannel
    local signal
    local subChannel = current_channel:getChannel(channelNamespaces[current_idx+1])
    result, signal = recursive_publish(channelNamespaces, current_idx+1, subChannel, result, ...)
    if signal == STOP then
      return result, STOP
    end

    -- publish to the matching wildcard subchannel
    if current_channel:hasChannel(WILDCARD) then
      local wildcardChannel = current_channel:getChannel(WILDCARD)
      result, signal = recursive_publish(channelNamespaces, current_idx+1, wildcardChannel, result, ...)
      if signal == STOP then
        return result, STOP
      end
    end

    -- finally publish to the current channel, marked as child-event
    return current_channel:_publish(result, true, ...)
  end



  --- Publishes to a channel (and its parents).
  -- @tparam array channelNamespaces The namespace-array of the channel to publish to (created if it doesn't exist).
  -- @param ... The arguments to pass to the subscribers.
  -- @treturn table The result table after all subscribers have been called.
  -- @usage
  -- local m = require("mediator")()
  -- m:publish({"car", "engine", "rpm"}, 1000, "rpm")
  function Mediator:publish(channelNamespaces, ...)
    return recursive_publish(channelNamespaces, 0, self.channel, {}, ...)
  end
end



--- Stops the mediator from calling the next subscriber.
-- @field STOP
-- @usage
-- local sub = mediator:addSubscriber({"channel"}, function()
--   result_data = {}
--   return mediator.STOP, result_data
-- end)
Mediator.STOP = STOP



--- Lets the mediator continue calling the next subscriber.
-- This is the default value if nothing is returned from a subscriber callback.
-- @field CONTINUE
-- @usage
-- local sub = mediator:addSubscriber({"channel"}, function()
--   result_data = {}
--   return mediator.CONTINUE, result_data
-- end)
Mediator.CONTINUE = CONTINUE



--- A wildcard value to be used in channel namespaces to match any namespace.
-- *Note*: when using wildcards, the priority will be to always call the named channel first,
-- and then the wildcard channel. So changing the priority of a subscriber has an effect
-- within the named or wildcard channel, but not between them.
-- @field WILDCARD
-- @usage
-- local sub = mediator:addSubscriber({"part1", mediator.WILDCARD, "part2"}, function()
--   print('This will be called for {"part1", "anything", "part2"}')
--   print('but also for: {"part1", "otherthing", "part2"}')
-- end)
Mediator.WILDCARD = WILDCARD



return Mediator