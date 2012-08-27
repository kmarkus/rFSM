--- rFSM discrete preview coordination
-- 
-- This extension extends transitions with a 'likely' predicate (side
-- effect free function) states with a 'prepare' function.. When the
-- source state is active and the likely function returns true, then
-- the prepare function of the target state is invoked.
--

local rfsm = require("rfsm")
local print, ipairs, pairs, error, type = print, ipairs, pairs, error, type

local actchild_get = rfsm.actchild_get

module 'rfsm_preview'

local function do_preview(fsm)
   local function preview_otrs(state)
      local likely=nil
      local prepare=nil
      for i,tr in ipairs(state._otrs) do
	 likely = tr.likely
	 if likely and likely(fsm) then
	    prepare = tr.tgt.prepare
	    if prepare then prepare(fsm) end
	 end
      end
   end

   local next = actchild_get(fsm)
   while next do
      preview_otrs(next)
      next = actchild_get(next)
   end
end

--- Setup preview coordination.
-- @param fsm initialized root fsm.
local function setup_preview(fsm)
   fsm.info("rfsm_preview: discrete preview extension loaded")
   
   rfsm.mapfsm(function (tr)
		  if tr.likely and type(tr.likely) ~= 'function' then
		     error("ERROR: invalid 'likely' attribute on " ..
			   tostring(tr)..". Should be a function")
		  end
	       end, fsm, rfsm.is_trans)

   rfsm.mapfsm(function (s)
		  if s.prepare and type(s.prepare) ~= 'function' then
		     error("ERROR: invalid 'prepare' attribute of " .. 
			   fsm._fqn .. ". Should be a function")
		  end
	       end, fsm, rfsm.is_state)
   rfsm.post_step_hook_add(fsm, do_preview)
end

-- install setup_preview as preproc hook
rfsm.preproc[#rfsm.preproc+1] = setup_preview