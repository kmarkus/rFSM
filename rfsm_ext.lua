-- useful but non essential rFSM extensions
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2020 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause
--

local rfsm = require("rfsm")
local utils = require("utils")
local math = math
local pairs = pairs
local ipairs = ipairs
local error = error
local type = type
local unpack = rawget(_G, "unpack") or table.unpack -- unpack is a global function for Lua 5.1, otherwise use table.unpack
local setmetatable = setmetatable
local print = print
local assert = assert
local error = error
local tostring = tostring

local M = {}

--- gen_monitor_state argument table
-- Description of the table expected by the gen_monitor_state function
-- @class table
-- @name montab
-- @field entry entry function of state (optional)
-- @field exit exit function of state (optional)
-- @field exit exit function of state (optional)
-- @field montab table of monitor functions (required). The index is
-- the event which will be raised if the function returns true
-- @field break_first if set to true rfsm.yield will be called
-- immediately after the first monitor function returns true, opposed
-- to the default behavior which first calls all functions before
-- calling yield, thereby possibly generating multiple events.

--- generate a monitor state
-- This function generates a rfsm simple_state which repeatedly calls
-- a list of monitor functions and raises an associated event if the
-- function returns true.
-- @param t montab table
-- @retval an rfsm.simple_state object

function M.gen_monitor_state(t)
   if t.montab==nil or type(t.montab) ~= 'table' then
      error("gen_monitor_state: missing or invalid 'montab' argument")
   end
   local break_first = t.breakfirst

   return rfsm.sista {
      entry = t.entry or nil,
      exit = t.exit or nil,

      doo = function(fsm)
	       while true do
		  for ev,monfun in pairs(t.montab) do
		     if monfun() then
			rfsm.send_events(fsm, ev)
			if break_first then break end
		     end
		  end
		  rfsm.yield()
	       end
	       return true
	    end
   }
end


--- Sequential AND state
M.seqand = {}
M.seqand.rfsm=true
function M.seqand:type() return 'state' end

--- Sequential AND state (experimental)
-- Permits declaration of multiple subfsm which are executed
-- sequentially. Events of the toplevel are forwarded to the subfsm
-- (but currently not back again).
--
-- parameters:
--   t.andseqdbg: if true print dbg information
--   t.idle_doo: returned in rfsm.yield(idle_doo) of seqand state.
--   t.step: number of steps to advance each subfsm (default: 1)
--   t.run: if true, don't step but run.
--   t.order: table of substate names that indicate the desired
--            execution order. Not mentioned states will be executed
--            after the ordered ones in arbitrary order.
--
-- @param t table initalized sub rfsms + above parameters
-- @return new seqand state
function M.seqand:new(t)
   setmetatable(t, self)
   self.__index = self

   if t.run and t.step then
      error("Sequential AND: states must define step _OR_ run")
   end

   if not ( t.run or t.step ) then
      t.step = 1
   end

   if t.step and (type(t.step) ~= 'number' or t.step <= 0) then
      error("Sequential AND: step must be a positive number")
   end

   if t.run then t.step = math.huge end
   if t.idle_doo == nil then t.idle_doo = true end

   -- create a regions table with all substates. Used to keep track
   -- which substates were already added to order.
   local regions = {}
   rfsm.mapfsm(function (cs, p, n) regions[n] = true end, t, rfsm.is_composite, 1)

   local exorder = {}

   -- first add states mentioned in t.order...
   if t.order then
      assert(type(t.order) == 'table', "seqand: t.order must be a table of string substate names.")
      local uniq_order = utils.table_unique(t.order);
      t.order=nil; -- not required anymore

      for _,name in ipairs(uniq_order) do
	 if not rfsm.is_composite(t[name]) then
	    error("andseq, 'order' field specifies non-existing state " .. name)
	 end
	 exorder[#exorder+1] = t[name]
	 regions[name]=nil
      end
   end

   -- ... then add the remaining at the end.
   for name,_ in pairs(regions) do exorder[#exorder+1] = t[name] end

   -- print some debug information
   if t.seqanddbg then
      print("andseq, found " .. #exorder .. " substates")
      -- build a state->name lookup tab
      local reg_lt = {}
      rfsm.mapfsm(function (cs, p, n) reg_lt[cs] = n end, t, rfsm.is_composite, 1)
      print("andseq, execution order:")
      for i,st in ipairs(exorder) do print("\t", tostring(i) ..". " .. reg_lt[st]) end
   end

   -- move all states in the sequential and state to a substates
   -- table, so that this state is still recognized as a leaf state
   -- (and hence is permitted to have a doo)
   local substates = rfsm.mapfsm(function (cs, st, name) return name end, t, rfsm.is_state, 1)
   t.substates={}
   for _,n in ipairs(substates) do t.substates[n]=t[n]; t[n]=nil; end

   local sh_saved
   -- entry install a new step hook (removed in exit) that intercepts
   -- and forward the current events to the child fsms.
   local function entry_hook (fsm)
      sh_saved=fsm.post_step_hook
      fsm.post_step_hook=function(fsm, events)
			    if sh_saved then sh_saved(fsm, events) end
			    if #events > 0 then
			       for _,subfsm in ipairs(exorder) do
				  rfsm.send_events(subfsm, unpack(events))
			       end
			    end
			 end
      for _,subfsm in ipairs(exorder) do rfsm.step(subfsm, t.step) end
   end
   t.entry=utils.advise('after', t.entry, entry_hook)

   t.doo=function(fsm)
	    while true do
	       for _,subfsm in ipairs(exorder) do rfsm.step(subfsm, t.step) end
	       rfsm.yield(t.idle_doo)
	    end
	 end

   local function exit_hook(fsm)
      fsm.post_step_hook=sh_saved
      for _,subfsm in ipairs(exorder) do
	 rfsm.exit_state(subfsm, subfsm)
	 rfsm.reset(subfsm)
      end
   end
   t.exit=utils.advise('before', t.exit, exit_hook)

   return t
end

-- nice constructor
setmetatable(M.seqand, {__call=M.seqand.new})

return M
