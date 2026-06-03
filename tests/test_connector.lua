-- Connector / compound-transition tests.
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

TestConnector = {}

-- simple connector chain: start -(eventA)-> conn -(eventB)-> end
local function simple_conn()
   return C.init(rfsm.csta{
      start = rfsm.sista{},
      conn = rfsm.conn{},
      ['end'] = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='start' },
      rfsm.trans{ src='start', tgt='conn', events={ 'eventA' } },
      rfsm.trans{ src='conn', tgt='end', events={ 'eventB' } },
   })
end

function TestConnector:test_partial_chain_not_taken()
   local fsm = simple_conn()
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.start")
   -- only the first segment is enabled -> chain must not advance
   C.send_run(fsm, 'eventA')
   lu.assert_equals(C.fqn(fsm), "root.start")
end

function TestConnector:test_full_chain_taken()
   local fsm = simple_conn()
   rfsm.run(fsm)
   -- both segments enabled in the same step -> whole chain fires
   C.send_run(fsm, 'eventA', 'eventB')
   lu.assert_equals(C.fqn(fsm), "root.end")
end

function TestConnector:test_split_connector()
   -- a connector that dispatches to different states based on events
   -- NB: avoid naming a state 'err'/'warn'/'info'/'dbg' as these collide
   -- with the toplevel printer/config fields.
   local fsm = C.init(rfsm.csta{
      operational = rfsm.sista{},
      faults = rfsm.csta{
         hardware_err = rfsm.sista{},
         software_err = rfsm.sista{},
         dispatch = rfsm.conn{},
         rfsm.trans{ src='initial', tgt='dispatch' },
         rfsm.trans{ src='dispatch', tgt='hardware_err', events={ 'e_hw' } },
         rfsm.trans{ src='dispatch', tgt='software_err', events={ 'e_sw' } },
      },
      rfsm.trans{ src='initial', tgt='operational' },
      rfsm.trans{ src='operational', tgt='faults.dispatch', events={ 'e_error' } },
      rfsm.trans{ src='faults', tgt='operational', events={ 'e_reset' } },
   })
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.operational")
   C.send_run(fsm, 'e_error', 'e_hw')
   lu.assert_equals(C.fqn(fsm), "root.faults.hardware_err")
   C.send_run(fsm, 'e_reset')
   lu.assert_equals(C.fqn(fsm), "root.operational")
   C.send_run(fsm, 'e_error', 'e_sw')
   lu.assert_equals(C.fqn(fsm), "root.faults.software_err")
end

function TestConnector:test_exit_connector()
   -- an exit connector of a composite leading to a sibling state
   local fsm = C.init(rfsm.csta{
      idle = rfsm.sista{},
      busy = rfsm.csta{
         one = rfsm.sista{},
         cexit = rfsm.conn{},
         rfsm.trans{ src='initial', tgt='one' },
         rfsm.trans{ src='one', tgt='cexit', events={ 'e_done' } },
      },
      recharging = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='idle' },
      rfsm.trans{ src='idle', tgt='busy', events={ 'e_start' } },
      rfsm.trans{ src='busy.cexit', tgt='recharging' },
   })
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.idle")
   -- e_start enters busy.one which completes (e_done), exit-conn fires to recharging
   C.send_run(fsm, 'e_start')
   lu.assert_equals(C.fqn(fsm), "root.recharging")
end

return TestConnector
