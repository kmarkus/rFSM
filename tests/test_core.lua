-- Core rFSM engine tests: states, transitions, guards, effects,
-- priority numbers, completion events and step/run semantics.
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

TestCore = {}

-- A minimal two-state machine reused by several tests.
local function on_off()
   return C.init(rfsm.csta{
      off = rfsm.sista{},
      on  = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='off' },
      rfsm.trans{ src='off', tgt='on', events={ 'e_on' } },
      rfsm.trans{ src='on', tgt='off', events={ 'e_off' } },
   })
end

function TestCore:test_initial_entry()
   local fsm = on_off()
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.off")
   lu.assert_equals(C.mode(fsm), "done")
end

function TestCore:test_event_transition()
   local fsm = on_off()
   rfsm.run(fsm)
   C.send_run(fsm, 'e_on')
   lu.assert_equals(C.fqn(fsm), "root.on")
   C.send_run(fsm, 'e_off')
   lu.assert_equals(C.fqn(fsm), "root.off")
end

function TestCore:test_unknown_event_no_transition()
   local fsm = on_off()
   rfsm.run(fsm)
   C.send_run(fsm, 'e_bogus')
   lu.assert_equals(C.fqn(fsm), "root.off")
end

function TestCore:test_init_rejects_non_state()
   lu.assert_error_msg_contains("invalid fsm model", function()
      rfsm.init({})
   end)
end

function TestCore:test_entry_exit_order()
   local log = {}
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{ entry=function() log[#log+1]='a_entry' end,
                      exit=function() log[#log+1]='a_exit' end },
      b = rfsm.sista{ entry=function() log[#log+1]='b_entry' end },
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ 'e_go' } },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_go')
   lu.assert_equals(log, { 'a_entry', 'a_exit', 'b_entry' })
end

function TestCore:test_guard_blocks_transition()
   local allow = false
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ 'e_go' },
                  guard=function() return allow end },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_go')
   lu.assert_equals(C.fqn(fsm), "root.a")  -- guard false: blocked
   allow = true
   C.send_run(fsm, 'e_go')
   lu.assert_equals(C.fqn(fsm), "root.b")  -- guard true: passes
end

function TestCore:test_effect_runs_and_receives_events()
   local seen
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ 'e_go' },
                  effect=function(f, tr, typ, events) seen = events end },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_go')
   lu.assert_equals(C.fqn(fsm), "root.b")
   lu.assert_is_table(seen)
   lu.assert_true(seen[1] == 'e_go')
end

function TestCore:test_priority_number()
   -- both transitions enabled by the same event; higher pn wins
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      lo = rfsm.sista{},
      hi = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='lo', events={ 'e' }, pn=1 },
      rfsm.trans{ src='a', tgt='hi', events={ 'e' }, pn=10 },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e')
   lu.assert_equals(C.fqn(fsm), "root.hi")
end

function TestCore:test_any_event_transition()
   -- a transition without events triggers on any event
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b' },  -- no events: any event
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'whatever')
   lu.assert_equals(C.fqn(fsm), "root.b")
end

function TestCore:test_reset()
   local fsm = on_off()
   rfsm.run(fsm)
   C.send_run(fsm, 'e_on')
   lu.assert_equals(C.fqn(fsm), "root.on")
   rfsm.reset(fsm)
   lu.assert_equals(fsm._act_leaf, false)
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.off")  -- back to initial
end

function TestCore:test_string_event_sugar()
   -- events may be given as a bare string instead of a one-element table
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events='e_go' },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_go')
   lu.assert_equals(C.fqn(fsm), "root.b")
end

function TestCore:test_predicate_event()
   -- a function event acts as a predicate matched against each event
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b',
                  events={ function(e) return type(e)=='string' and e:match('^e_err') end } },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_other')
   lu.assert_equals(C.fqn(fsm), "root.a")   -- predicate does not match
   C.send_run(fsm, 'e_error_42')
   lu.assert_equals(C.fqn(fsm), "root.b")   -- predicate matches
end

function TestCore:test_get_active_conf()
   local fsm = C.init(rfsm.csta{
      outer = rfsm.csta{
         inner = rfsm.sista{},
         rfsm.trans{ src='initial', tgt='inner' },
      },
      rfsm.trans{ src='initial', tgt='outer' },
   })
   lu.assert_equals(rfsm.get_active_conf(fsm), {})   -- inactive
   rfsm.run(fsm)
   lu.assert_equals(rfsm.get_active_conf(fsm),
                    { "root", "root.outer", "root.outer.inner" })
end

function TestCore:test_step_hook_add_rm()
   local fsm = on_off()
   rfsm.run(fsm)
   local n = 0
   local function hook() n = n + 1 end
   rfsm.post_step_hook_add(fsm, hook)
   rfsm.step(fsm)
   local after_add = n
   lu.assert_true(after_add > 0)
   lu.assert_true(rfsm.post_step_hook_rm(fsm, hook))
   rfsm.step(fsm)
   lu.assert_equals(n, after_add)            -- not called after removal
   lu.assert_false(rfsm.post_step_hook_rm(fsm, hook))  -- already gone
end

function TestCore:test_load_str()
   local templ = rfsm.load_str([[
      local rfsm = require("rfsm")
      return rfsm.csta{ x = rfsm.sista{}, rfsm.trans{ src='initial', tgt='x' } }
   ]], "inline_fsm")
   local fsm = C.init(templ)
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.x")
end

function TestCore:test_load_str_rejects_non_state()
   lu.assert_error_msg_contains("valid rfsm", function()
      rfsm.load_str("return 42")
   end)
end

function TestCore:test_relative_and_local_refs()
   local fsm = C.init(rfsm.csta{
      operational = rfsm.csta{
         motors_on = rfsm.csta{
            moving = rfsm.sista{},
            stopped = rfsm.sista{},
            rfsm.trans{ src='initial', tgt='stopped' },
         },
         rfsm.trans{ src='initial', tgt='motors_on' },
      },
      off = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='.operational.motors_on.moving' },
      rfsm.trans{ src='.operational.motors_on.stopped', tgt='off', events={ 'e_off' } },
   })
   rfsm.run(fsm)
   -- relative initial transition refined entry to moving
   lu.assert_equals(C.fqn(fsm), "root.operational.motors_on.moving")
end

return TestCore
