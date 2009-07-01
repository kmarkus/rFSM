-- sample fsm which simply toggles between on and off states

fsm = { 
   -- debug = true, default is off
   -- no_warn defaults to false
   -- no_warn = true,
   initial_state = "off", 
   queue = { "on-button" },
   states = { { 
		 name = "on", 
		 entry = function () print('entry ON') end,
		 doo = "print('inside on do')", 
		 exit = "print('inside on exit')", 
		 transitions = { { event="off-button", target="off", effect="print('in transition to off')" } } },
	      { 
		 name = "off", 
		 entry = "print('entry OFF')", 
		 doo = "print('inside off do')", 
		 exit = "print('inside off exit')",
		 transitions = { { event="on-button", target="on", effect="print('in transition to on')" } } }
	   }
}

-- here we go
require("umlfsm")
send, step = umlfsm.send, umlfsm.step

umlfsm.init(fsm)
send(fsm, "on-button")
send(fsm, "off-button")
send(fsm, "on-button")
send(fsm, "invalid-event")
send(fsm, "on-button")
send(fsm, "off-button")

step(fsm)
os.execute("sleep 0.5")
step(fsm)
os.execute("sleep 0.5")
step(fsm)
os.execute("sleep 0.5")
step(fsm)
os.execute("sleep 0.5")
step(fsm)
os.execute("sleep 0.5")
step(fsm)
os.execute("sleep 0.5")
step(fsm)
