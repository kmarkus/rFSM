require "rfsm"

local csta = rfsm.csta

return rfsm.csta{

   operational = rfsm.sista{},
   calibration = rfsm.sista{},

   error = csta{
      hardware_err = rfsm.sista{},
      software_err = rfsm.sista{},
      err_dispatch = rfsm.conn{},

      rfsm.trans{ src='initial', tgt='err_dispatch' },
      rfsm.trans{ src='err_dispatch', tgt='hardware_err', events={"e_hw_err" } },
      rfsm.trans{ src='err_dispatch', tgt='software_err', events={"e_sw_err" } },
   },

   rfsm.trans{ src='initial', tgt='operational' },
   rfsm.trans{ src='operational', tgt='error.err_dispatch', events={"e_error" } },
   rfsm.trans{ src='calibration', tgt='error.err_dispatch', events={"e_error" } },
   rfsm.trans{ src='error', tgt='operational', events={"e_error_reset" } },
}
