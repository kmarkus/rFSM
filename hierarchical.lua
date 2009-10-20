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
   transitions = { { event='e_foo', tgt='internal' } }
}


-- transitions:
--  - regular:  src='source-state', tgt='target-state', event='e_bla', guard=function () return true end
--  - internal: src=not_allowed, tgt='internal', event='e_bla', guard=...
--  - initial:  src='initial', tgt='target-state', event=not_allowed!, guard=...
--  - final:    src='source-state', tgt='final', event=..., giard=...


-- parallel state
--   - 'parallel': table of composite or parallel states

orthogonal_region = {
   id = 'homing',
   parallel={ { id = 'cs_home_ax1',
		states = { { id='home_axis1', doo="homeAxis()" } },
		transitions = { { src='initial', tgt='home_axis1' },
				{ src='home_axis1', tgt='final' } } },
	      { id = 'cs_home_ax2',
		states = { { id='home_axis2', doo="homeAxis()" } },
		transitions = { { src='initial', tgt='home_axis2' },
				{ src='home_axis2', tgt='final' } } },
	      { id = 'cs_home_ax3',
		states = { { id='home_axis3', doo="homeAxis()" } },
		transitions = { { src='initial', tgt='home_axis3' },
				{ src='home_axis3', tgt='final' } } } }
}

-- composite state
--   - must have 'initial': string of initial state in 'states'
--   - states is a table of simple, composite or parallel states
--   - must *not* have doo, only simple states may have that
--   - the tgt 'final' will exit the composite state
--   - the tgt 'terminate' will do exactly that to the fsm

parallel = {
   id = 'motor_control',
   entry = nil,
   exit = nil,

   -- a table of simple states
   states = { {
		 id = 'off',
		 entry = function () print("off: entry") end,
		 doo = function () print("off: doo") end,
		 exit = function () print("off: exit") end
	      },
	      {
		 id = 'on',
		 entry = function () turn_motor_on() end,
		 doo = function () print("on: doo") end,
		 exit = function () print("on: exit") end
	      },
	      orthogonal_region,
	   },
   transitions = { { src='initial', tgt='off' },
		   { src='homing', tgt='off', event='e_complete' },
		   { src='on', tgt='off', event='e_off' },
		   { src='on', tgt='homing', event='e_home' },
		   { src='off', tgt='on', event='e_on' },
		   { src='off', tgt='homing', event='e_quit' } }
}

root = {
   id = 'rtt_toplevel',
   states = { {
		 id = 's_init',
		 entry = 'print("initalizing")',
		 exit = 'print("exiting s_init state")' },
	      {
		 id = 's_stopped',
		 entry = 'print("entering s_stopped state")' },
	      {
		 id = 's_running',
		 states = { {
			       id = 's_working',
			       entry = 'print("entering state s_working ")',
			       doo = 'print("processing in state s_working")' },
			    {
			       id = 's_obj_close',
			       entry = 'print("entering s_obj_close state")',
			       doo = 'print("processing in s_obj_close_state")' } },
		 transitions = { { src='initial', tgt='s_working' },
				 { event='e_obj_close', src='s_working', tgt='s_obj_close' },
				 { event='e_range_free', src='s_obj_close', tgt='s_working'} } } },

   transitions = { { src='initial', tgt='s_init' },
		   { src='s_running', tgt='s_stopped', event='e_stopped' },
		   { src='s_stopped', tgt='s_init', event='e_reset', effect='print("reseting")' },
		   { src='s_stopped', tgt='s_running', event='e_start', effect='print("restarting")' },
		   { src='s_stopped', tgt='final', event='e_quit' },
		   { src='s_init', tgt='s_running', event='e_start',  } }
}


local fsm0 = rtfsm.init(simple)
if fsm0 then
   fsm2img.fsm2img(simple, "png", simple.id .. ".png")
else
   print("failed to init " .. simple.id)
end

local fsm1 = rtfsm.init(root)
if fsm1 then
   fsm2img.fsm2img(root, "png", root.id .. ".png")
else
   print("failed to init " .. root.id)
end

local fsm2 = rtfsm.init(parallel)
if fsm2 then
   fsm2img.fsm2img(parallel, "png", parallel.id .. ".png")
else
   print("failed to init " .. parallel.id)
end


-- os.execute("qiv" .. " *.png")
