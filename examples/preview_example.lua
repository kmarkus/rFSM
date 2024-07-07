--- Simple preview coordination example.
-- When approaching a grasp position we consider it likely that the
-- grasp will take place, hence it is desireable to already start
-- positioning the arm in a convenient position. The likely predicate
-- defines which transition is likely when (here: always the
-- transition to 'grasping'). Grasping itself defines how "itself" can
-- be prepared by providing a 'prepare' function, that is called when
-- and while a transition to grasping becomes/is likely.

local rfsm = require("rfsm")
local rfsm_timeevent = require("rfsm_timeevent")
local ac=require("ansicolors")

local state, trans = rfsm.state, rfsm.trans

rfsm_timeevent.set_gettime_hook(function () return os.time(), 0 end)

function prnt(...) print(ac.green(ac.bright(table.concat({...}, '\t')))) end

--- FSM 
return state { 
   idle_hook=function() uml(); os.execute("sleep 0.5") end,
  
   approach_grasp_pos = state {
      entry=function () prnt("approaching grasp position") end
   },

   grasping = state {
      prepare=function() prnt("pre-positioning arm for grasp") end,
      entry=function() prnt("executing grasp") end
   },

   drop_off = state{
      entry=function() prnt("dropped off object") end,
   },

   trans{ src='initial', tgt='approach_grasp_pos' },
   trans{ src='approach_grasp_pos', tgt='grasping', 
	  events={ 'e_after(5)' },
	  likely=function() return true end -- static high probability of transitioning
       },
   trans{ src='grasping', tgt='drop_off', events={ 'e_done' } },
   trans{ src='drop_off', tgt='approach_grasp_pos', events={ 'e_after(5)' } },
}
