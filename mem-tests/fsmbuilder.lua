require("rtfsm")

local rtfsm, math, print, assert = rtfsm, math, print, assert

module("fsmbuilder")

local function printer_gen(s)
   return function (...) print(s, unpack(arg)) end
end

-- create a flat fsm with num_chained states connected.  progs is a
-- table with optional entry, doo, exit functions used for checking
-- garbage collection after state transitions

function flat_chain_fsm(num_states, progs)
   assert(num_states >= 2, "num_states must be > 2")
   local progs = progs or {}
   local event_list = { "e_trigger" }

   local fsm_tmpl = rtfsm.csta:new{ entry=printer_gen("entering root"),
				    err=print, warn=true, info=false, dbg=false }

   fsm_tmpl['s' .. 1] = rtfsm.sista:new{ entry=progs.entry, doo=progs.doo, exit=progs.exit }

   for i=2,num_states do
      fsm_tmpl['s' .. i] = rtfsm.sista:new{ entry=progs.entry, doo=progs.doo, exit=progs.exit }
      fsm_tmpl[#fsm_tmpl+1] = rtfsm.trans:new{ src='s' .. i-1, tgt='s' .. i, events=event_list }
   end

   -- wrap
   fsm_tmpl[#fsm_tmpl+1] = rtfsm.trans:new{ src='s' .. num_states, tgt='s1', events=event_list }

   -- create initial
   fsm_tmpl[#fsm_tmpl+1] = rtfsm.trans:new{ src='initial', tgt='s1' }

   return fsm_tmpl
end

--
-- construct a flat, random fsm with num_states and num_transitions
--
-- used to determine memory allocation
function rand_fsm(num_states, num_trans)
     
   assert(num_states >= 2, "num states must be > 2")
   assert(num_trans > 0)

   local fsm_tmpl = rtfsm.csta:new{ entry=printer_gen("entering root"),
				    doo=printer_gen("inside doo"),
				    err=print, warn=false, info=false }

   -- generate states
   for i = 1,num_states do
      fsm_tmpl['s' .. i] = rtfsm.sista:new{ entry=printer_gen("entering s" .. i),
					    exit=printer_gen("entering s" .. i) }
   end

   -- generate transitions
   for i = 1,num_trans do
      fsm_tmpl[#fsm_tmpl+1] = rtfsm.trans:new{ src='s' .. math.random(num_states),
					       tgt='s' .. math.random(num_states),
					       events={'e_' .. i} }
   end

   fsm_tmpl[#fsm_tmpl+1] = rtfsm.trans:new{ src='initial', tgt='s1' }

   return fsm_tmpl
end
