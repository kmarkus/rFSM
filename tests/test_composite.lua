-- Composite / nested state tests, including the shipped example models.
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

TestComposite = {}

function TestComposite:test_nested_entry_and_transitions()
   local fsm = C.init(rfsm.csta{
      operational = rfsm.csta{
         approaching = rfsm.sista{},
         in_contact  = rfsm.sista{},
         rfsm.trans{ src='initial', tgt='approaching' },
         rfsm.trans{ src='approaching', tgt='in_contact', events={ 'e_contact_made' } },
         rfsm.trans{ src='in_contact', tgt='approaching', events={ 'e_contact_lost' } },
      },
      safe = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='safe' },
      rfsm.trans{ src='safe', tgt='operational', events={ 'e_range_clear' } },
      rfsm.trans{ src='operational', tgt='safe', events={ 'e_close_object' } },
   })
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.safe")
   C.send_run(fsm, 'e_range_clear')
   lu.assert_equals(C.fqn(fsm), "root.operational.approaching")
   C.send_run(fsm, 'e_contact_made')
   lu.assert_equals(C.fqn(fsm), "root.operational.in_contact")
   -- a transition leaving the composite from any internal state
   C.send_run(fsm, 'e_close_object')
   lu.assert_equals(C.fqn(fsm), "root.safe")
end

function TestComposite:test_reentry_uses_initial()
   local fsm = C.init(rfsm.csta{
      operational = rfsm.csta{
         a = rfsm.sista{},
         b = rfsm.sista{},
         rfsm.trans{ src='initial', tgt='a' },
         rfsm.trans{ src='a', tgt='b', events={ 'e_ab' } },
      },
      safe = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='safe' },
      rfsm.trans{ src='safe', tgt='operational', events={ 'e_op' } },
      rfsm.trans{ src='operational', tgt='safe', events={ 'e_safe' } },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_op')
   C.send_run(fsm, 'e_ab')
   lu.assert_equals(C.fqn(fsm), "root.operational.b")
   C.send_run(fsm, 'e_safe')   -- leave composite
   C.send_run(fsm, 'e_op')     -- re-enter: must use initial -> a
   lu.assert_equals(C.fqn(fsm), "root.operational.a")
end

-- the shipped example models should load and initialize cleanly
function TestComposite:test_example_models_load()
   local models = {
      "composite_nested", "composite_exitconn",
      "connector_simple", "connector_split", "hello_world",
      "simple_doo_idle", "simple_idle_doo", "relative_trans",
      "subgraphs",
   }
   for _, name in ipairs(models) do
      local templ = rfsm.load(C.example(name))
      templ.info = false; templ.warn = false
      local fsm = rfsm.init(templ)
      lu.assert_not_nil(fsm, "init of example " .. name .. " failed")
      lu.assert_true(fsm._initialized)
   end
end

return TestComposite
