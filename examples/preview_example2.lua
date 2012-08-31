--- Simple preview coordination example.
-- Variant that shows how the prepare function can be setup to only be
-- called once.


require "rfsm_timeevent"
require "rfsm_preview"
local ac=require "ansicolors"
local state, trans = rfsm.state, rfsm.trans

rfsm_timeevent.set_gettime_hook(function () return os.time(), 0 end)

function prnt(...) print(ac.green(ac.bright(table.concat({...}, '\t')))) end

--- Generate a one shot function.
-- Generate a wrapper function that, when called, will call the function
-- supplied as an argument exactly once. After that it must be reset
-- using the reload function.
-- @param func function to be called once
-- @return one shot function
-- @return reload function
function gen_call_it_once(func)
   local loaded=true

   local function reload() loaded=true end

   local function caller(...)
      if loaded then loaded=false; return func(...) end
   end
   return caller, reload
end



-- here we generate the one-shot prepare function and the
-- reloader. These are then used in the FSM below:
pre_pos_arm, reload_pre_pos_arm = gen_call_it_once(
   function () prnt("pre-positioning arm for grasp") end
)

--- FSM 
return state { 
   idle_hook=function() uml(); os.execute("sleep 0.5") end,
  
   approach_grasp_pos = state {
      entry=function () prnt("approaching grasp position") end
   },

   grasping = state {
      prepare=pre_pos_arm,
      entry=function() prnt("executing grasp") end
   },

   drop_off = state{
      entry=function() prnt("dropped off object") end,
   },

   trans{ src='initial', tgt='approach_grasp_pos' },
   trans{ src='approach_grasp_pos', tgt='grasping', 
	  events={ 'e_after(5)' },
	  likely=function() return true end, -- static high probability of transitioning
	  effect=reload_pre_pos_arm,
       },
   trans{ src='grasping', tgt='drop_off', events={ 'e_done' } },
   trans{ src='drop_off', tgt='approach_grasp_pos', events={ 'e_after(5)' } },
}