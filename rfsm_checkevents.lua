-- Checkevents rFSM plugin
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2020 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- this little plugin checks if the received events are actually
-- events that may trigger transitions and prints a warning message
-- otherwise.
--
local rfsm = require("rfsm")

local M = {}

local function setup_checkevents(fsm)

   local function check_events(known, cur)
      for _, e in ipairs(cur) do
	 if not known[e] then
	    fsm.warn("WARNING: undeclared event "..tostring(e).. " received")
	 end
      end
   end

   fsm.info("rfsm_checkevents: checkevents extension loaded")

   -- build list of known events   
   local known_events = {
      e_init_fsm=true,
   }

   rfsm.mapfsm(function(t)
		  local events = t.events or {}
		  for _,e in ipairs(events) do
		     known_events[e] = true 
		  end
	       end, fsm, rfsm.is_trans)
   
   rfsm.mapfsm(function(s)
		  known_events["e_done@"..s._fqn]=true
	       end, fsm, rfsm.is_state)

   local pre_step_hook = function(fsm, curq)
			    check_events(known_events, curq)
			 end

   rfsm.pre_step_hook_add(fsm, pre_step_hook)
end

rfsm.preproc[#rfsm.preproc+1] = setup_checkevents

return M
