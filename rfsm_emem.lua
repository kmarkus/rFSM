--- rFSM memory extension.
-- This extensions adds "memory" to an rFSM chart. This is done by
-- adding a table <code>emem</code> to states.
--
-- Implementationwise a pre_step handler is installed that runs
-- through the current active list and for each state sets
-- emem[event]+=1 .
-- Moreover, the exit function is extended to clear the
-- emem table of the state that is left.
--

local rfsm = require("rfsm")
local print, ipairs, pairs = print, ipairs, pairs


module 'rfsm_emem'

--- Reset the event memory of a state
-- @param state the state of which memory shall be cleared.
function emem_reset(s)
   local et = s.emem
   if et then
      for e,x in pairs(et) do et[e] = 0 end
   end
end

--- Update all emem tables with the current events.
-- This function expects to be called from pre_step_hook.
-- @param fsm initialized root fsm
-- @param events table of events
local function update_emem_tabs(fsm, events)
   local function update_emem_tab(fsm, s)
      local et = s.emem
      for i,e in ipairs(events) do
	 if not et[e] then et[e] = 1
	 else et[e]=et[e] + 1 end
      end
   end
   if fsm._act_leaf then
      rfsm.map_from_to(fsm, update_emem_tab, fsm._act_leaf, fsm)
   end
end


--- Setup event memory for the given fsm.
-- @param fsm initialized root fsm.
local function setup_emem(fsm)

   -- mapfsm does not call f() on the root itself.
   fsm.emem={}

   -- create emem tables
   rfsm.mapfsm(function (s, p)
		  print("setting emem tab in state " .. s._fqn)
		  s.emem={}
	       end, fsm, rfsm.is_sta)

   -- install pre_step_hook
   if not fsm.pre_step_hook then
      fsm.pre_step_hook= update_emem_tabs
   else
      local oldfun = fsm.pre_step_hook
      fsm.pre_step_hook=function (fsm) oldfun(fsm); update_emem_tabs(fsm); end
   end

   rfsm.mapfsm(function (s, p)
		  if s.exit then
		     local oldexit = s.exit
		     s.exit = function (fsm, state, type)
				 oldexit(fsm, state, type)
				 emem_reset(state)
			      end
		  else
		     s.exit = function (fsm, state, type) emem_reset(state) end
		  end
	       end, fsm, rfsm.is_sta)


   -- install clearing of emem contents in exit hooks
   -- todo!

end


rfsm.preproc[#rfsm.preproc+1] = setup_emem