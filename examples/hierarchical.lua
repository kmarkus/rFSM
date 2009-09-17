--
-- simple hierarchical fsm
--

-- example fsm

--  simple state
-- constraints: 
--   - must have 'id' field
--   - transitions:
--      - event can be table or string (tbd. types)
--      - target is string, must exist
--      - guard can be function or string

simple = {
   id = 'simple_state',
   entry = function () print("simple_state: entry") end,
   doo = function () print("simple_state: doo") end,
   exit = function () print("simple_state: exit") end,
   transitions = { { event='e_quit', target='final', guard=function () return 2>1 end },
		   { event='e_foo', target='internal' } },
   deferred = { 'e_bla', 'e_blurb' }
}

-- composite state
--   - must have 'initial': string of initial state in 'states'
--   - states is a table of simple, composite or parallel states
--   - must *not* have doo, only simple states may have that
--   - the target 'final' will exit the composite state
--   - the target 'terminate' will do exactly that to the fsm

composite = {
   id = 'motor_control',
   entry = nil,
   exit = nil,
   
   initial = 'off',
   transitions = { { event='entryOff', target='off' },
		   { event='entryOn', target='on' } },
   
   -- a table of simple states
   states = { {
		 name = 'off',
		 entry = function () print("off: entry") end,
		 doo = function () print("off: doo") end,
		 exit = function () print("off: exit") end,
		 transitions = { { event='e_quit', target='final' },
				 { event='e_on', target='on' } }
	      },
	      {
		 name = 'on',
		 entry = function () turn_motor_on() end,
		 doo = function () print("on: doo") end,
		 exit = function () print("on: exit") end,
		 transitions = { { event='e_off', target='off' } } 
	      }
	   }
}

-- parallel state
--   - 'parallel': table of composite or parallel states
orthogonal_region = {
   parallel={ composite, composite }
}

root = {
   id = 'rtt_toplevel',
   initial = 's_init',
   states = { {
		 name = 's_init', 
		 entry = 'print("initalizing")',
		 exit = 'print("exiting s_init state")',
		 transitions = { { event='e_start', target='s_running' } } }, 
	      {
		 name = 's_stopped',
		 entry = 'print("entering s_stopped state")',
		 transitions = { { event='e_reset', target="s_init", effect='print("reseting")' },
				 { event='e_start', target="s_running", effect='print("restarting")' } } },
	      {
		 name = 's_running',
		 initial = 's_working',
		 states = { { 
			       name = 's_working',
			       entry = 'print("entering state s_working ")',
			       doo = 'print("processing in state s_working")',
			       transitions = { { event = 'e_obj_close', target = 's_obj_near' } } }, 
			    { 
			       name = 's_obj_close',
			       entry = 'print("entering s_obj_close state")',
			       doo = 'print("processing in s_obj_close_state")',
			       transitions = { { event = 'e_range_free', target = 's_working' } } }
			 },
		 transitions = { { event='e_stopped', target='s_stopped' } }
	      }
 	   }
}

-- andFSM = {
--    name = 'orthogonal_test',
--    parallel = { {
-- 		   doo = function ()
-- 			    do_step()
-- 			    coroutine.yield()
-- 			 end
-- 		}, {
		   
-- 	  } } }


-- here we go
-- require('umlfsm')

-- umlfsm.init(root)

-- umlfsm.send(root, 'e_start')
-- umlfsm.send(root, 'e_obj_close')
-- umlfsm.send(root, 'e_range_free')

-- umlfsm.step(root)
