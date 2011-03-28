
local rfsm = require ("rfsm")
local json = require("json")
local utils = require ("utils")
local pcall = pcall
local tostring = tostring

module("rfsm2json")

-- shortcuts
local mapfsm = rfsm.mapfsm
local is_trans = rfsm.is_trans
local is_csta, is_sista, is_trans, is_conn, is_fsmobj = rfsm.is_csta, rfsm.is_sista, rfsm.is_trans, rfsm.is_conn, rfsm.is_fsmobj

local VERSION = 1

--- Convert an initialized rFSM instance to the json representation
-- @param fsm initalized rFSM instance
function encode(fsm)
   --- convert a transition to a table
   -- @param t rfsm.transition
   local function trans2tab(t)
      --- safely convert an event to a string
      -- @param e arbitrary event type that supports __tostring
      local function ev2str(e)
	 local res, evstr = pcall(tostring, e)
	 if res then return evstr
	 else return "?" end
      end
      return { type='transition', src=t.src._fqn, tgt=t.tgt._fqn,
	       pn=t.pn, events=utils.map(ev2str, t.events) }
   end
   
   --- convert (sub-) fsm s to a table
   local function __rfsm2json(s)
      if is_sista(s) then
	 return { id=s._id, type='simple' }
      elseif is_conn(s) then
	 return { id=s._id, type='connector' }
      elseif is_csta(s) then
	 local tab = { id=s._id, type='composite' }
	 tab.transitions = mapfsm(trans2tab, s, is_trans, 1)
	 tab.subnodes = mapfsm(__rfsm2json, s, is_fsmobj, 1)
	 return tab
      end
   end

   if not fsm._initialized then
      error("rfsm2json: initialized fsm required")
      return false
   end

   local res = { version=VERSION }
   res.fsm_graph = __rfsm2json(fsm)
   if fsm._act_leaf then
      res.active_leaf = { fqn=fsm._act_leaf._fqn, state=get_sta_mode(fsm._act_leaf) }
   else 
      res.active_leaf = false
   end
   return json.encode(res)
end

