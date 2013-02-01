---
--- Simple example to illustrate the await plugin.
--
-- In a nutshell, this plugin permits to trigger transitions only
-- after multiple events have been received. These events can be
-- received in different steps.
--
-- This is basically a specialized version of the emem plugin. This
-- one should be preferred if no counting is required, since it is
-- computationally much less expensive.
--
-- Behavior:
-- When loaded, the plugin scans for events with the syntax
-- await(event1, event2)". This statement is transformed as follows:
--
--  - a guard condition is generated and added to possibly existing
--    guard conditions. It will only enable the transition if the both
--    events have been received while the source state is active.
--
--  - a second hook is installed in the exit function of the source
--    state to reset the event counting. So when the source state is
--    exited (either via or not via the await transition) and
--    reentered again, the counting start from the beginning. It would
--    be trivial to provide a variant of await that resets the counts
--    only if the await transition is taken, however it is not clear
--    to me right now if that would be useful at all.
--

require "rfsm_await"
require "rfsmpp"

x= rfsm.state {
   notready=rfsm.state{},

   ready=rfsm.state{
      off=rfsm.state{},
      on=rfsm.state{},

      rfsm.trans{ src='initial', tgt='off' },

      -- this transiton will only be enabled after e_motor_on and
      -- e_checks_passed have been received.
      rfsm.trans{ src='off', tgt='on', events={"await(e_motor_on, e_checks_passed)"} },

      -- this is a regular transition triggering on 'e_stop'
      rfsm.trans{ src='on', tgt='off', events={"e_stop"} },
   },

   rfsm.trans{src='initial', tgt='notready'},
   rfsm.trans{src='notready', tgt='ready', events={'e_ready'}},

}

x.dbg=rfsmpp.gen_dbgcolor("await", { STATE_ENTER=true, STATE_EXIT=true, AWAIT=true,
				     EFFECT=true, HIBERNATING=true, RAISED=true}, false)

fsm=rfsm.init(x)

-- enter the fsm
rfsm.run(fsm)

-- send e_motor_on, no transition
rfsm.send_events(fsm,'e_motor_on')
rfsm.run(fsm)

-- send a bogus event, no transition
rfsm.send_events(fsm,'e_foo')
rfsm.run(fsm)

-- send a e_checks_passed, transition as both
rfsm.send_events(fsm,'e_checks_passed')
rfsm.run(fsm)

-- send a e_checks_passed, transition as both
rfsm.send_events(fsm,'e_ready')
rfsm.run(fsm)

-- a single events takes us back to off
rfsm.send_events(fsm,'e_checks_passed')
rfsm.run(fsm)
