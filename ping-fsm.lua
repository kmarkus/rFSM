--
-- a "self feeding" fsm which generates events itself
--

max_trans = 100000
tcnt = 0

fsm = { 
   initial_state = "pinging",
   states = { { 
		 name = "pinging", 
		 entry = function () 
			    if tcnt < max_trans then
			       umlfsm.send(fsm, "pong") 
			 end end,
		 transitions = { { event="pong", 
				   target="ponging", 
				   effect="tcnt=tcnt+1" } } },
	      { 
		 name = "ponging", 
		 entry = "umlfsm.send(fsm, 'ping')",
		 transitions = { { event="ping",
				   target="pinging", 
				   effect="tcnt=tcnt+1" } } } 
	   }
}

require("umlfsm")

-- here we go
umlfsm.init(fsm)
umlfsm.run(fsm, math.huge)

print("total transitions: ", tcnt)
