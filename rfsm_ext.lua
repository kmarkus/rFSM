--
-- useful but non essential rFSM extensions
--

local rfsm = require("rfsm")
local pairs = pairs
local error = error
local type = type

module("rfsm_ext")

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

function gen_monitor_state(t)
   local entry_func = t.entry or nil
   local exit_func = t.exit or nil
   if t.montab==nil or type(t.montab) ~= 'table' then
      error("gen_monitor_state: missing or invalid 'montab' argument")
   end
   local break_first = t.breakfirst

   return rfsm.sista:new{
      entry=entry_func,
      exit=exit_func,
      
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
