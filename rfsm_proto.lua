
local socket = require("socket")
local json = require("json")
local rfsm = require("rfsm")
local rfsm_marsh = require("rfsm_marsh")
local utils = require("utils")

local os = os
local pairs = pairs
local print = print
local assert = assert
local type = type

module("rfsm_proto")

--- Default configuration
local host = "localhost" 	-- use '*' for host to bind to all local interfaces.
local port = 44044

local read_timeout = 1		-- block in read for this time
local heartbeat_timeout = 15	-- drop a subscriber after not receiving a heartbeat for this time
local idle_update = 3		-- send a state update after this time if no changes take place.

local VERSION=2

-- messages: All messages have a type and a version field plus
-- additional fields depending on the type.

-- Incoming:
--   type: 'subscribe'
--   type: 'unsubscribe'
--   type: 'heartbeat'

-- Outgoing
--   type: 'rfsm_model': sent initially or when the model changes
--      'model'=rfsm2json output

--   type: 'rfsm_active_state': sent when a state change occurs
--      'act_leaf': new active leaf
--      'path':     path taken to reach this state

--- Update heartbeat timestamp.
function update_timestamp(key, subs)
   -- print("received heartbeat from " .. key)
   if subs[key] then subs[key].last_heartbeat = os.time() end
end

-- Send updated state information to all subscribers
-- TODO: Extend this to only send state if it changed or once every X seconds.
function send_state(inf)
   local subs, sock = inf.subscribers, inf.socket
   local act_leaf, state, path = inf.getactleaf()

   inf.cnt_state_update = inf.cnt_state_update + 1
   for key, sub in pairs(subs) do
      sock:sendto(json.encode{type='rfsm_active_state',
			      act_leaf=act_leaf,
			      act_leaf_state=state,
			      path=path,
			      cnt=inf.cnt_state_update,
			      version=VERSION },
		  sub.ip, sub.port)
   end
end

-- Process timeouts and drop zombies.
function process_timeouts(inf)
   local subs, sock = inf.subscribers, inf.socket
   local cur_time = os.time()
   utils.foreach(
      function(sub, id)
	 if cur_time - sub.last_heartbeat > heartbeat_timeout then
	    subs[id] = nil -- drop it
	    print("No heartbeat from " .. id .. " since " .. heartbeat_timeout .. "s - dropping")
	    inf.cnt_subs_timeout = inf.cnt_subs_timeout + 1
	 end
      end, inf.subscribers)
end

--- Add a new subscriber
-- @param subs list of subscribers
-- @param ip ip address
-- @param port port
function add_subscriber(ip, port, inf)
   local key = ip..':'..port
   local subs, sock = inf.subscribers, inf.socket
   if subs[key] then print("Resubscribing " .. key )
   else print("Subscribing " .. key) end
   local model = inf.getmodel()
   subs[key] = { last_heartbeat=os.time(), ip=ip, port=port }
   sock:sendto( json.encode{ type='rfsm_model',
			     graph=model,
			     cnt=inf.cnt_model_update,
			     version=VERSION }, ip, port)
end

--- Remove a subscriber
function rm_subscriber(ip, port, subs)
   local key = ip..':'..port
   subs[key] = nil
end

-- subscribers = {
--   ['ip:port']={ last_heartbeat=sec, ip=IP, port=PORT },
--   ['ip:port']={ last_heartbeat=sec, ip=IP, port=PORT },
--   ...
-- }

function dispatch(msg, ip, port, inf)
   local msg_type = msg.type
   local key = ip..':'..port
   local subs = inf.subscribers

   -- dispatch
   if msg_type == 'subscribe' then add_subscriber(ip, port, inf)
   elseif msg_type == 'unsubscribe' then rm_subscriber(ip, port, subs)
   elseif msg_type  == 'heartbeat' then update_timestamp(key, subs) end
end

function process(inf)
   local sock, subs = inf.socket, inf.subscribers
   local data, ip, port = sock:receivefrom() -- data is max 8k
   if data then
      local msg = json.decode(data)
      dispatch(msg, ip, port, inf)
   -- else
   --    print("Timeout " .. ip)
   end
   -- if os.time() - last_update > idle_update then send_state(sock, subscribers) end
   send_state(inf)
   process_timeouts(inf)
end

--- generate a function that processes an update
-- @param conf table with the following fields:
--  read_timeout
--  host
--  port
--
function gen_updater(conf)
   -- initalize
   local sock = assert(socket.udp())
   local read_timeout = conf.read_timeout or read_timeout
   local host = conf.host or host
   local port = conf.port or port

   assert(type(conf.getmodel)=='function')
   assert(type(conf.getactleaf)=='function')

   assert(sock:setsockname(host, port))
   assert(sock:settimeout(read_timeout))

   -- the main information structure
   local proto_inf = {
      socket = sock,
      subscribers = {},
      last_update=0,

      getmodel = conf.getmodel,
      getactleaf = conf.getactleaf,

      -- counters/statistics
      cnt_state_update = 0,
      cnt_model_update = 0,
      cnt_subs_timeout = 0,
   }

   return function () process(proto_inf) end
end

function setup_proto(fsm)
   local getmodel = function () return rfsm_marsh.model2tab(fsm) end
   local getactleaf = function () return rfsm_marsh.actinfo2tab(fsm) end
   local updater = gen_updater({read_timeout=0,
				getmodel=getmodel,
				getactleaf=getactleaf })
   rfsm.post_step_hook_add(fsm, updater)
end

rfsm.preproc[#rfsm.preproc+1] = setup_proto