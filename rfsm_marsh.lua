-- rfsm marshalling functions
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2020 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause
--

local rfsm = require ("rfsm")
local utils = require ("utils")
local pcall = pcall
local tostring = tostring
local print = print -- debugging only

module("rfsm_marsh")

-- shortcuts
local mapfsm = rfsm.mapfsm
local get_sta_mode = rfsm.get_sta_mode
local is_composite = rfsm.is_composite
local is_leaf = rfsm.is_leaf
local is_conn = rfsm.is_conn
local is_node = rfsm.is_node
local is_trans = rfsm.is_trans

--- Convert an initalized fsm to a table
function model2tab(fsm)
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
	       pn=t.pn, events=utils.imap(ev2str, t.events) }
   end

   --- convert (sub-) fsm s to a table
   local function __rfsm2tab(s)
      if is_leaf(s) then
	 return { id=s._id, type='state' }
      elseif is_conn(s) then
	 return { id=s._id, type='connector' }
      elseif is_composite(s) then
	 local tab = { id=s._id, type='state' }
	 tab.transitions = mapfsm(trans2tab, s, is_trans, 1)
	 tab.subnodes = mapfsm(__rfsm2tab, s, rfsm.is_nr_node, 1)
	 return tab
      end
   end

   if not fsm._initialized then
      error("rfsm2tab: initialized fsm required")
      return false
   end

   return __rfsm2tab(fsm)
end

--- Return the active state of an rFSM.
-- @return active leaf state fqn
-- @return state of that fqn
-- @return transition path taken to last state
function actinfo2tab(fsm)
   if fsm._act_leaf then
      return fsm._act_leaf._fqn, get_sta_mode(fsm._act_leaf), false
   end
   return false, false, false
end
