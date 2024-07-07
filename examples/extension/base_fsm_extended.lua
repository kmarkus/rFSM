local rfsm = require("rfsm")
local state, trans, conn = rfsm.state, rfsm.trans, rfsm.conn

local fsm_model=rfsm.load("base_fsm.lua")

-- add an new state
fsm_model.emergency = state {
   entry=function()
	    print("performing emergency shutdown") 
	 end,
}

fsm_model[#fsm_model+1] = trans{src='on', tgt='emergency', events={'e_emergency'} }
fsm_model[#fsm_model+1] = trans{src='emergency', tgt='on', events={'e_emergency_recovered'} }

return fsm_model
