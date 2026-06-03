-- Time-event extension tests, using a controllable virtual clock.
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

local NSEC_PER_SEC = 1000000000

TestTimeevent = {}

-- virtual clock shared by the tests (nanoseconds)
local now = 0
local function advance(seconds) now = now + seconds * NSEC_PER_SEC end

function TestTimeevent:setUp()
   local te = require("rfsm.timeevent")
   te.set_gettime_hook(function() return now end)
   self.e_after = te.e_after
   now = 0
end

function TestTimeevent:test_fires_after_timeout()
   local e_after = self.e_after
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ e_after(0.1) } },
   })
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.a")
   -- not enough time has passed yet
   advance(0.05); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.a")
   -- now past the timeout: the post-step check raises the event, the
   -- following step consumes it.
   advance(0.1); rfsm.run(fsm); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.b")
end

function TestTimeevent:test_timeout_via_function()
   local e_after = self.e_after
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ e_after(function() return 0.2 end) } },
   })
   rfsm.run(fsm)
   advance(0.1); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.a")
   advance(0.15); rfsm.run(fsm); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.b")
end

function TestTimeevent:test_timer_restarts_on_reentry()
   local e_after = self.e_after
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ e_after(0.1) } },
      rfsm.trans{ src='b', tgt='a', events={ 'e_back' } },
   })
   rfsm.run(fsm)
   advance(0.2); rfsm.run(fsm); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.b")
   -- back to a: the timer must restart, so a small advance is not enough
   C.send_run(fsm, 'e_back')
   lu.assert_equals(C.fqn(fsm), "root.a")
   advance(0.05); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.a")
   advance(0.1); rfsm.run(fsm); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.b")
end

function TestTimeevent:test_e_at_absolute()
   local te = require("rfsm.timeevent")
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ te.e_at(100) } },  -- absolute t=100s
   })
   rfsm.run(fsm)
   now = 50 * NSEC_PER_SEC; rfsm.run(fsm); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.a")  -- absolute time not reached
   now = 101 * NSEC_PER_SEC; rfsm.run(fsm); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.b")  -- past the absolute time
end

function TestTimeevent:test_legacy_string_syntax()
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ "e_after(0.1)" } },  -- old string form
   })
   rfsm.run(fsm)
   advance(0.2); rfsm.run(fsm); rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.b")
end

return TestTimeevent
