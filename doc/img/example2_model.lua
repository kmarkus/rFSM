-- Model used to render doc/img/example2.png (the "more complete
-- example" from the README).
local rfsm = require("rfsm")

return rfsm.state {
   on = rfsm.state {
      moving = rfsm.state {},
      waiting = rfsm.state {},
      rfsm.trans{ src='initial', tgt='waiting' },
      rfsm.trans{ src='waiting', tgt='moving', events={ 'e_start' } },
      rfsm.trans{ src='moving', tgt='waiting', events={ 'e_stop' } },
   },
   error = rfsm.state {},
   fatal_error = rfsm.state {},

   rfsm.trans{ src='initial', tgt='on' },
   rfsm.trans{ src='on', tgt='error', events={ 'e_error' } },
   rfsm.trans{ src='error', tgt='on', events={ 'e_error_fixed' } },
   rfsm.trans{ src='error', tgt='fatal_error', events={ 'e_fatal_error' } },
   rfsm.trans{ src='fatal_error', tgt='initial', events={ 'e_reset' } },
}
