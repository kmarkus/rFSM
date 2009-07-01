--
-- simple dummy example
--

fsm = { 
   initial_state = "off",
   queue = {},
   states = { { 
		 name = "on", 
		 entry = "print('starting work')",
		 exit = "print('stopping work')",
		 transitions = { { event="off-event", 
				   target="off" } } },
	      { 
		 name = "off", 
		 transitions = { { event="on-event",
				   target="on",
				   effect="print('starting up')" } } }
	   }
}

-- here we go
require("umlfsm")

umlfsm.init(fsm)

umlfsm.send(fsm, "on-event")
umlfsm.send(fsm, "off-event")
umlfsm.send(fsm, "on-event")
umlfsm.send(fsm, "on-event")
umlfsm.send(fsm, "off-event")

umlfsm.run(fsm, 6)
