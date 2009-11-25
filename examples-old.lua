--
-- FSM examples
--

require("fsm2uml")
require("fsm2tree")
require("rtfsm")
require("utils")

make_state=fsmutils.make_state

---
-- best practices:
--
-- 1) Don't depend on persistent events -> robustness against lost events
--	- persistent instead of deferrable events?
---

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
   -- ? transitions = { { event='e_foo', tgt='internal' } }
}


-- transitions:
--  - regular:  src='source-state', tgt='target-state', event='e_bla', guard=function () return true end
--  - internal: src=source-state, tgt='internal', event='e_bla', guard=...
--  - initial:  src='initial', tgt='target-state', event=not_allowed!, guard=...
--  - final:    src='source-state', tgt='final', event=..., giard=...


-- parallel state
--   - 'parallel': table of composite or parallel states

orthogonal_region = {
   id = 'homing',
   parallel={ { id = 'cs_home_ax1',
		states = { { id='home_axis1', doo="homeAxis()" } },
		transitions = { { src='initial', tgt='home_axis1' },
				{ src='home_axis1', tgt='final', event='e_complete' } } },
	      { id = 'cs_home_ax2',
		states = { { id='home_axis2', doo="homeAxis()" } },
		transitions = { { src='initial', tgt='home_axis2' },
				{ src='home_axis2', tgt='final', event='e_complete' } } },
	      { id = 'cs_home_ax3',
		states = { { id='home_axis3', doo="homeAxis()" } },
		transitions = { { src='initial', tgt='home_axis3' },
				{ src='home_axis3', tgt='final', event='e_complete' } } } }
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
		   { src='homing', tgt='final', event='e_complete' },
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
		   { src='s_init', tgt='s_running', event='e_start',  } },

   connectors = { { id='initial' }, { id='final' }, { id="x12" } }
}

hitball = {
   id = 'hit_the_ball_demo',
   states = { {
		 id = 'operational',
		 states = { { id = 'follow' },
			    { id = 'hit'} },
		 transitions = { { src='follow', tgt='hit', event='e_hit_ball' },
				 { src='hit', tgt='follow', event='e_hit_done', effect='wait 2s' } }
	      }, {
		 id = 'calibration'
	   } },
   transitions = { { src='hit_the_ball_demo.operational.follow', tgt='calibration', event='e_calibrate' },
		   { src='calibration', tgt='operational', event='e_calibrate_done' } }

}


-- variant to be discussed
-- make id the table index:
-- advantages:
--  - root.states.state2.states.state3 works
--   (maybe nicer would be to omit 'states' table so that root.state2.state3 becomes possible)
--  - id is separate from the state, better reuse. How deal with parameters?
--
hitball2 = {
   id = 'hit_the_ball_demo',
   states = { operational = {
		 states = { { id = 'follow' },
			    { id = 'hit'} },
		 transitions = { { src='follow', tgt='hit', event='e_hit_ball' },
				 { src='hit', tgt='follow', event='e_hit_done', effect='wait 2s' } }
	      },
	      calibration = { id = 'calibration' } },
   transitions = { { src='hit_the_ball_demo.operational.follow', tgt='calibration', event='e_calibrate' },
		   { src='calibration', tgt='operational', event='e_calibrate_done' } }

}

-- or better
hitball3 = {
   id = 'hit_the_ball_demo',
   operational = {
      follow = { entry="Scene.follow=true", exit="do_that()" },
      hit = { },
      transitions = { { src='follow', tgt='hit', event='e_hit_ball' },
		      { src='hit', tgt='follow', event='e_hit_done', effect='wait 2s' } }
   },

   calibration = { },

   transitions = { { src='hit_the_ball_demo.operational.follow', tgt='calibration', event='e_calibrate' },
		   { src='calibration', tgt='operational', event='e_calibrate_done' } }

}


--
--
-- currently fails because resolve logic can't find calibration
--
-- hitball2 = utils.deepcopy(hitball)
-- hitball2.id = 'hit_the_ball_demo'
-- hitball2.transitions[1] = { src='follow', tgt='calibration', event='e_calibrate' }

os.execute("rm -f *.png")

-- murky auxillary function
local function do_all(_fsm)
   print("Processing FSM '" .. _fsm.id .. "'")
   local fsm = rtfsm.init(_fsm)
   if not fsm then
      print("ERROR: init failed")
      return false
   end
   fsm2uml.fsm2uml(fsm, "png", fsm.id .. "-uml.png")
   fsm2tree.fsm2tree(fsm, "png", fsm.id .. "-tree.png")
   print(string.rep('-', 80))
   return fsm
end

fsmt = utils.map(do_all, {simple, root, parallel, hitball})
--  fsm_hitball2 = do_all(hitball2)

os.execute("qiv" .. " *.png")
