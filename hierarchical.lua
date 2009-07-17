--
-- simple hierarchical fsm
--

-- valid types: simple, composite, 


running = {
   initial = 's_working',
   type = 'composite',
   states = { { name = 's_working',
		type = 'simple',
		entry = 'print("entering state s_working ")',
		doo = 'print("processing in state s_working")',
		transitions = { { event = 'e_obj_close', target = 's_obj_near' } },
	     } { name = 's_obj_close',
		 type = 'simple',
		 entry = 'print("entering s_obj_close state")',
		 doo = 'print("processing in s_obj_close_state")',
		 transitions = { { event = 'e_range_free',
				   target = 's_working' } } }
	   }
}

rtt_toplevel = {
   initial = 'init',
   states = { {
		 name = 's_init', 
		 type = 'simple',
		 entry = 'print("initalizing")',
		 exit = 'print("exiting s_init state")',
		 transitions = { { event='e_start', 
				   target='s_running' } },
	      } {
		 name = 's_stopped',
		 type = 'simple'
		 entry = 'print("entering s_stopped state")',
		 transitions = { { event='e_reset', target="s_init", effect='print("reseting")' } },
		 transitions = { { event='e_start', target="s_running", effect='print("restarting")' } } 
	      },
	      running,
	   }
}


-- here we go
require('umlfsm')

umlfsm.init(fsm)

umlfsm.send(fsm, 'e_start')
umlfsm.send(fsm, 'e_obj_close')
umlfsm.send(fsm, 'e_range_free')

umlfsm.run(fsm, 6)
