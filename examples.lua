--
-- RTFSM examples
--

require("fsm2uml")
require("fsm2tree")
require("rtfsm")
require("utils")

local sista = rtfsm.simple_state
local csta = rtfsm.composite_state
local psta = rtfsm.parallel_state
local trans = rtfsm.transition
local conn = rtfsm.connector
local join = rtfsm.join
local fork = rtfsm.fork

-- simple state
-- required: -
-- optional: entry, doo, exit
simple = sista:new {
   entry = function () print("sista: entry") end,
   doo = function () print("sista: doo") end,
   exit = function () print("sista: exit") end
}

-- composite state
-- required: -
-- optional: entry, exit, states, transitions
-- disallowed: doo
composite_homing = csta:new{
   home = sista:new{ doo="homeAxis" },
   trans:new{ src='initial', tgt='home' },
   trans:new{ src='home', tgt='home' }
}

-- parallel state
-- required: --
-- optional: composite states, parallel states, connectors, join, fork
-- disallowed: sista
homing_cstate = psta:new {
   cs_home_ax1 = csta:new{
      home_axis1 = sista:new{ doo="homeAxis()" },
      trans:new{ src='initial', tgt='home_axis1' },
      trans:new{ src='home_axis1', tgt='final', events='completed(home_axis1)' }
   },
   cs_home_ax2 = csta:new{
      home_axis2 = sista:new{ doo="homeAxis()" },
      trans:new{ src='initial', tgt='home_axis2' },
      trans:new{ src='home_axis2', tgt='final', events='completed(home_axis2)' }
   },
   cs_home_ax3 = csta:new{
      home_axis3 = sista:new{ doo="homeAxis()" },
      trans:new{ src='initial', tgt='home_axis3' },
      trans:new{ src='home_axis3', tgt='final', events='completed(home_axis3)' }
   } 
}

-- root: composite state with additional constraints:
-- required: 'initial' connector
-- disallowed: -
root_ex1 = csta:new{
   entry=nil,
   exit=nil,
   
   -- states
   off = sista:new{
      entry = function () print("off: entry") end,
      doo = function () print("off: doo") end,
      exit = function () print("off: exit") end
   },
   on = sista:new{
      entry = function () turn_motor_on() end,
      doo = function () print("on: doo") end,
      exit = function () print("on: exit") end
   },
   homing = homing_cstate,

   -- transitions
   trans:new{ src='initial', tgt='off' },
   trans:new{ src='homing', tgt='final', event='e_complete' },
   trans:new{ src='on', tgt='off', event='e_off' },
   trans:new{ src='on', tgt='homing', event='e_home' },
   trans:new{ src='off', tgt='on', event='e_on' },
   trans:new{ src='off', tgt='homing', event='e_quit' }
}
   
root_rtt_toplevel = {
   sista:new{ entry = 'print("initalizing")', exit = 'print("exiting s_init state")' },
   sista:new{ entry = 'print("entering s_stopped state")' },

   csta:new{
      s_working = sista:new{ 
	 entry = 'print("entering state s_working ")',
	 doo = 'print("doo in state s_working")' },
      s_obj_close = sista:new{ 
	 entry = 'print("entering s_obj_close state")',
	 doo = 'print("processing in s_obj_close_state")' },
      trans:new{ src='initial', tgt='s_working' },
      trans:new{ event='e_obj_close', src='s_working', tgt='s_obj_close' },
      trans:new{ event='e_range_free', src='s_obj_close', tgt='s_working'}
   },

   trans:new{ src='initial', tgt='s_init' },
   trans:new{ src='s_running', tgt='s_stopped', event='e_stopped' },
   trans:new{ src='s_stopped', tgt='s_init',
		   event='e_reset', effect='print("reseting")' },
   trans:new{ src='s_stopped', tgt='s_running',
		   event='e_start', effect='print("restarting")' },
   conn:new{ src='s_stopped', tgt='final', event='e_quit' },
   conn:new{ src='s_init', tgt='s_running', event='e_start'}
}


os.execute("rm -f *.png")

-- murky auxillary function
local function do_all(_fsm)
   print("Processing FSM '" .. tostring(_fsm) .. "'")
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

fsmt = utils.map(do_all, {simple, homing_cstate, root_ex1, root_rtt_toplevel})
--  fsm_hitball2 = do_all(hitball2)

os.execute("qiv" .. " *.png")
