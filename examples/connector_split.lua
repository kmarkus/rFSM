
require "rfsm"

local csta = rfsm.csta

return rfsm.csta:new{

   operational = rfsm.sista:new{},
   calibration = rfsm.sista:new{},

   error = csta:new{
      hardware_err = rfsm.sista:new{},
      software_err = rfsm.sista:new{},
      err_dispatch = rfsm.conn:new{},
      
      rfsm.trans:new{ src='initial', tgt='err_dispatch' },
      rfsm.trans:new{ src='err_dispatch', tgt='hardware_err', events={"e_hw_err" } },
      rfsm.trans:new{ src='err_dispatch', tgt='software_err', events={"e_sw_err" } },
   },

   rfsm.trans:new{ src='initial', tgt='operational' },
   rfsm.trans:new{ src='operational', tgt='error.err_dispatch', events={"e_error" } },
   rfsm.trans:new{ src='calibration', tgt='error.err_dispatch', events={"e_error" } },
   rfsm.trans:new{ src='error', tgt='operational', events={"e_error_reset" } },
}
