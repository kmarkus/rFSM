--
-- FSM examples
--

require("fsm2img")
require("rtfsm")

make_state=rtfsm.make_state

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
		   { event='e_foo', target='internal' } }
}


-- parallel state
--   - 'parallel': table of composite or parallel states

s_homing_tmpl = {
   id='test',
   doo = "homeAxis()",
   transitions = { { event='e_completion', target='final' } }
}

cs_homing_1 = {
   id = 'cs_home_ax1',
   initial = 'home_axis1',
   states = { make_state(s_homing_tmpl, { id='home_axis1', param={ axis=1 } }) }
}

cs_homing_2 = {
   id = 'cs_home_ax2',
   initial = 'home_axis2',
   states = { make_state(s_homing_tmpl, { id='home_axis2', param={ axis=2 } }) }
}

cs_homing_3 = {
   id = 'cs_home_ax3',
   initial = 'home_axis3',
   states = { make_state(s_homing_tmpl, { id='home_axis3', param={ axis=3 } }) }
}
      
orthogonal_region = {
   id = 'homing',
   parallel={ cs_homing_1, cs_homing_2, cs_homing_3 },
   transitions = { { event=" e_complete ", target='off' } }
}

-- composite state
--   - must have 'initial': string of initial state in 'states'
--   - states is a table of simple, composite or parallel states
--   - must *not* have doo, only simple states may have that
--   - the target 'final' will exit the composite state
--   - the target 'terminate' will do exactly that to the fsm

parallel = {
   id = 'motor_control',
   entry = nil,
   exit = nil,
   
   initial = 'off',
      
   -- a table of simple states
   states = { {
		 id = 'off',
		 entry = function () print("off: entry") end,
		 doo = function () print("off: doo") end,
		 exit = function () print("off: exit") end,
		 transitions = { { event=' e_quit ', target='homing' },
				 { event=' e_on ', target='on' } }
	      },
	      {
		 id = 'on',
		 entry = function () turn_motor_on() end,
		 doo = function () print("on: doo") end,
		 exit = function () print("on: exit") end,
		 transitions = { { event=' e_off ', target='off' },
				 { event=' e_home ', target='homing' } }

	      },
	      orthogonal_region,
	   }
}


root = {
   id = 'rtt_toplevel',
   initial = 's_init',
   states = { {
		 id = 's_init', 
		 entry = 'print("initalizing")',
		 exit = 'print("exiting s_init state")',
		 transitions = { { event='e_start', target='s_running' } } }, 
	      {
		 id = 's_stopped',
		 entry = 'print("entering s_stopped state")',
		 transitions = { { event='e_reset', target="s_init", effect='print("reseting")' },
				 { event='e_start', target="s_running", effect='print("restarting")' } } },
	      {
		 id = 's_running',
		 initial = 's_working',
		 states = { { 
			       id = 's_working',
			       entry = 'print("entering state s_working ")',
			       doo = 'print("processing in state s_working")',
			       transitions = { { event = 'e_obj_close', target = 's_obj_close' } } }, 
			    { 
			       id = 's_obj_close',
			       entry = 'print("entering s_obj_close state")',
			       doo = 'print("processing in s_obj_close_state")',
			       transitions = { { event = 'e_range_free', target = 's_working' } } }
			 },
		 transitions = { { event='e_stopped', target='s_stopped' } }
	      }
 	   }
}

if rtfsm.init(root) then
   fsm2img.fsm2img(root, "png", "root.png")
else
   print("failed to init root fsm")
end

-- os.execute("qiv" .. " *.png")
