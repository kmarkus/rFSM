--- Example to illustrate the event memory extension.
-- This example has two main states: ping and pong. In each state the
-- events 'e_ping' and 'e_pong' are raised respectively. Guard
-- conditions between these two states take place when the respective
-- event has occured often enough (according to the defined limits).
--
-- A top limit to break the loop is set by examining the memory of the
-- parent ('root'). This will enable a transition to 'final' Because
-- 'root' always is active it records the complete event history of
-- the state machine (unless a self transition on root is executed,
-- which would reset roots history too). Therefore, when transitioning
-- to final the history is manually cleared in final.entry using the
-- emem_reset function.

require "rfsm"
require "rfsm_emem"

local ping_max = 5
local pong_max = 40000
local final_max = 100000

return rfsm.csta {
   ping = rfsm.sista{
      doo=function (fsm)
	     while true do
		rfsm.send_events(fsm, 'e_ping')
		rfsm.yield()
	     end
	  end,
   },

   pong = rfsm.sista{
      doo=function (fsm)
	     while true do
		rfsm.send_events(fsm, 'e_pong')
		rfsm.yield()
	     end
	  end,
   },

   final = rfsm.sista {
      entry=function (fsm)
	       rfsm_emem.emem_reset(fsm)
	       print("done state entered, send 'e_restart' to continue")
	    end
   },

   -- initial -> ping
   rfsm.trans{ src='initial', tgt='ping' },

   -- ping -> pong
   rfsm.trans{ src='ping', tgt='pong',
	       guard=function (tr)
			-- check: if 'e_ping' has occured more than 5
			-- times enable guard. Important: emem.e_ping
			-- might be nil if e_ping has not occured, so
			-- check!
			local x = tr.src.emem.e_ping
			if x and x > ping_max then return true end
			return false
		     end,
	       effect=function() print("to pong") end },

   -- pong -> ping
   rfsm.trans{ src='pong', tgt='ping',
	       guard=function (tr)
			local x = tr.src.emem.e_pong
			if x and x > pong_max then return true end
			return false
		     end,
	       effect=function() print("to ping") end },

   -- ping -> final
   rfsm.trans{ src='ping', tgt='final',
	       guard=function (tr)
			-- check if and how often 'e_ping' occured
			-- while in the parent of the ping state (in
			-- root). If amount is more than the defined
			-- limit enable guard to permit exit. The
			-- _parent field of a state always returns the
			-- parent composite state. (Note: _parent (as
			-- anything starting with '_') is not yet part
			-- of the standard API and hence might change)
			local x = tr.src._parent.emem.e_pong
			if x and x > final_max then return true end
			return false
		     end,
	       effect=function() print("to final") end },

   -- final -> ping (manual restart)
   rfsm.trans { src='final', tgt='ping', events={'e_restart'} },

}