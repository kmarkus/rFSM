--
-- a "self feeding" fsm which generates events itself
--

max_trans = 100000
tcnt = 0

fsm = { 
   inital_state = "pinging",
   queue = { "pong" },
   states = { { 
		 name = "pinging", 
		 entry = function () 
			    if tcnt < max_trans then
			       send(fsm, "pong") 
			 end end,
		 transitions = { { event="pong", 
				   target="ponging", 
				   effect="tcnt=tcnt+1" } } },
	      { 
		 name = "ponging", 
		 entry = "send(fsm, 'ping')",
		 transitions = { { event="ping",
				   target="pinging", 
				   effect="tcnt=tcnt+1" } } } 
	   }
}

-- here we go
init(fsm)

-- math.huge is an infinite number
run(fsm, math.huge)
print("total transitions: ", tcnt)
