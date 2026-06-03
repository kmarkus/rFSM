-- Tests for the optional rFSM extensions: emem, await, checkevents,
-- the monitor-state helper and sequential-AND states.
--
-- NOTE: extensions install *global* preproc hooks (rfsm.preproc) the
-- first time they are require()d.  We therefore require them inside the
-- individual test methods so they do not leak into the other suites
-- that are loaded by run.lua.
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

TestExtensions = {}

function TestExtensions:test_emem_counts_across_steps()
   require("rfsm.emem")
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      -- guard fires only once 'e_tick' has been seen twice, possibly
      -- across different steps (which plain transitions cannot do)
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ 'e_tick' },
                  guard=function(tr) return (tr.src.emem['e_tick'] or 0) >= 2 end },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_tick')
   lu.assert_equals(C.fqn(fsm), "root.a")   -- only one tick so far
   C.send_run(fsm, 'e_tick')
   lu.assert_equals(C.fqn(fsm), "root.b")   -- second tick -> guard passes
end

function TestExtensions:test_emem_reset_on_exit()
   require("rfsm.emem")
   local emem = require("rfsm.emem")
   local fsm = C.init(rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ 'e_go' } },
      rfsm.trans{ src='b', tgt='a', events={ 'e_back' } },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_unrelated')          -- counted into a.emem
   lu.assert_true((fsm.a.emem['e_unrelated'] or 0) >= 1)
   C.send_run(fsm, 'e_go')                 -- exit a -> emem reset
   lu.assert_equals(fsm.a.emem['e_unrelated'], 0)
end

function TestExtensions:test_await_multiple_events()
   require("rfsm.await")
   local fsm = C.init(rfsm.csta{
      off = rfsm.sista{},
      on  = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='off' },
      rfsm.trans{ src='off', tgt='on', events={ "await(e_a, e_b)" } },
      rfsm.trans{ src='on', tgt='off', events={ 'e_reset' } },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_a')
   lu.assert_equals(C.fqn(fsm), "root.off")  -- only one of two await events
   C.send_run(fsm, 'e_b')
   lu.assert_equals(C.fqn(fsm), "root.on")   -- both received -> fires
end

function TestExtensions:test_await_resets_on_exit()
   require("rfsm.await")
   local fsm = C.init(rfsm.csta{
      off = rfsm.sista{},
      on  = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='off' },
      rfsm.trans{ src='off', tgt='on', events={ "await(e_a, e_b)" } },
      rfsm.trans{ src='on', tgt='off', events={ 'e_reset' } },
   })
   rfsm.run(fsm)
   C.send_run(fsm, 'e_a', 'e_b')             -- -> on
   C.send_run(fsm, 'e_reset')                -- -> off (await reset)
   C.send_run(fsm, 'e_a')
   lu.assert_equals(C.fqn(fsm), "root.off")  -- counting restarted
   C.send_run(fsm, 'e_b')
   lu.assert_equals(C.fqn(fsm), "root.on")
end

function TestExtensions:test_checkevents_warns_on_unknown()
   require("rfsm.checkevents")
   local warns = {}
   local templ = rfsm.csta{
      info = false,
      warn = function(...) warns[#warns+1] = table.concat({...}, " ") end,
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ 'e_known' } },
   }
   local fsm = rfsm.init(templ)
   rfsm.run(fsm)
   rfsm.send_events(fsm, 'e_unknown_xyz')
   rfsm.run(fsm)
   local found = false
   for _, w in ipairs(warns) do
      if w:match("undeclared event e_unknown_xyz") then found = true end
   end
   lu.assert_true(found, "expected a warning about the undeclared event")
end

function TestExtensions:test_monitor_state()
   local ext = require("rfsm.ext")
   local trip = false
   local fsm = C.init(rfsm.csta{
      watching = ext.gen_monitor_state{
         montab = { e_alarm = function() return trip end },
      },
      alarmed = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='watching' },
      rfsm.trans{ src='watching', tgt='alarmed', events={ 'e_alarm' } },
   })
   -- the monitor doo yields non-idle, so it must be *stepped* (run()
   -- would spin forever while the monitor never raises an event)
   rfsm.step(fsm, 5)
   lu.assert_equals(C.fqn(fsm), "root.watching")  -- monitor not tripped
   trip = true
   rfsm.step(fsm, 5)
   lu.assert_equals(C.fqn(fsm), "root.alarmed")   -- monitor raised e_alarm
end

function TestExtensions:test_seqand()
   local ext = require("rfsm.ext")
   -- shared observation table; the 'two' entry sets a flag.  We observe
   -- through entry side effects rather than the sub-fsm structure,
   -- because seqand steps the original sub-fsms (not the deep-copied
   -- ones reachable via .substates).
   local reached = {}
   local function sub(id)
      return rfsm.init(rfsm.csta{
         dbg=false, info=false, warn=false,
         one = rfsm.sista{},
         two = rfsm.sista{ entry=function() reached[id] = true end },
         rfsm.trans{ src='initial', tgt='one' },
         rfsm.trans{ src='one', tgt='two', events={ 'e_next' } },
      })
   end
   local fsm = C.init(rfsm.csta{
      off = rfsm.sista{},
      both = ext.seqand{
         r1 = sub('r1'),
         r2 = sub('r2'),
      },
      rfsm.trans{ src='initial', tgt='off' },
      rfsm.trans{ src='off', tgt='both', events={ 'e_on' } },
      rfsm.trans{ src='both', tgt='off', events={ 'e_off' } },
   })
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.off")
   C.send_run(fsm, 'e_on')
   lu.assert_equals(C.fqn(fsm), "root.both")
   lu.assert_nil(reached.r1)              -- sub-regions still in 'one'
   -- the forwarded event must advance both sub-regions to 'two'
   C.send_run(fsm, 'e_next')
   lu.assert_true(reached.r1)
   lu.assert_true(reached.r2)
   C.send_run(fsm, 'e_off')
   lu.assert_equals(C.fqn(fsm), "root.off")
end

return TestExtensions
