-- sample fsm which simply toggles between on and off states

function print_x_times(mes, x, sleep)
   while x > 0 do
      x = x - 1
      print(mes)
      os.execute("sleep " .. sleep)
      coroutine.yield()
   end
end

fsm1 = { 
   -- debug = true, default is off
   -- no_warn defaults to false
   -- no_warn = true,
   initial_state = "s_off", 
   states = { { 
		 name = "s_on", 
		 entry = function () print('entry s_on') end,
		 doo = function ()
			  print_x_times("inside s_on doo", 10, 1)
		       end,
		 exit = "print('inside s_on exit')", 
		 transitions = { { event="e_off", target="s_off", effect="print('in transition to s_off')" } } },
	      { 
		 name = "s_off", 
		 entry = "print('entry s_off')", 
		 doo = function ()
			  print_x_times("inside s_off doo", 10, 3)
		       end,
		 exit = "print('inside s_off exit')",
		 transitions = { { event="e_on", target="s_on", effect="print('in transition to s_on')" } } }
	   }
}

-- here we go
require("umlfsm")
send, step = umlfsm.send, umlfsm.step

umlfsm.init(fsm1)
send(fsm1, "e_on")
-- send(fsm1, "e_off")
-- send(fsm1, "e_on")
-- send(fsm1, "invalid-event")
-- send(fsm1, "e_on")
-- send(fsm1, "e_off")

step(fsm1)
