-- Tests for doo functions (coroutines), completion events and idle flag.
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

TestDoo = {}

function TestDoo:test_leaf_without_doo_completes_immediately()
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
   })
   rfsm.run(fsm)
   lu.assert_equals(C.mode(fsm), "done")  -- no doo -> immediately done
end

function TestDoo:test_doo_runs_to_completion_raises_e_done()
   local count = 0
   local fsm = C.init(rfsm.csta{
      work = rfsm.sista{ doo=function()
                            for _=1,3 do count = count + 1; rfsm.yield() end
                         end },
      finished = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='work' },
      -- e_done is the completion event of the source state
      rfsm.trans{ src='work', tgt='finished', events={ 'e_done' } },
   })
   rfsm.run(fsm)
   lu.assert_equals(count, 3)
   lu.assert_equals(C.fqn(fsm), "root.finished")
end

function TestDoo:test_doo_can_raise_events()
   -- a doo that raises an event which triggers a transition out
   local fsm = C.init(rfsm.csta{
      monitoring = rfsm.sista{ doo=function(f)
                                  rfsm.send_events(f, 'e_trigger')
                                  rfsm.yield(true)
                               end },
      alarm = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='monitoring' },
      rfsm.trans{ src='monitoring', tgt='alarm', events={ 'e_trigger' } },
   })
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.alarm")
end

function TestDoo:test_event_preempts_doo()
   -- an external event interrupts a long-running (idle) doo
   local fsm = C.init(rfsm.csta{
      busy = rfsm.sista{ doo=function() while true do rfsm.yield(true) end end },
      idle = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='busy' },
      rfsm.trans{ src='busy', tgt='idle', events={ 'e_stop' } },
   })
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.busy")  -- doo idle, stays put
   lu.assert_equals(C.mode(fsm), "active")
   C.send_run(fsm, 'e_stop')
   lu.assert_equals(C.fqn(fsm), "root.idle")
end

function TestDoo:test_idle_flag_keeps_state_active()
   local fsm = C.init(rfsm.csta{
      busy = rfsm.sista{ doo=function() while true do rfsm.yield(true) end end },
      rfsm.trans{ src='initial', tgt='busy' },
   })
   local idle = rfsm.run(fsm)
   lu.assert_true(idle)                       -- run returns idle
   lu.assert_equals(C.mode(fsm), "active")    -- but the doo is still active
end

function TestDoo:test_step_count()
   -- step(n) returns false while steps remain, true once idle
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ 'e_go' } },
   })
   rfsm.step(fsm)  -- enter
   lu.assert_equals(C.fqn(fsm), "root.a")
end

return TestDoo
