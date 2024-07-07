-- simple sample state machine which defines an idle doo
local rfsm = require("rfsm")

return rfsm.csta{

   on = rfsm.sista{},
   off = rfsm.sista{},
   busy = rfsm.sista{ doo=function() rfsm.yield(true) end },

   rfsm.trans{ src='initial', tgt='off' },
   rfsm.trans{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans{ src='on', tgt='off', events={ 'e_off' } },
   rfsm.trans{ src='off', tgt='busy', events={ 'e_busy' } },
   rfsm.trans{ src='busy', tgt='off', events={ 'e_done' } },
}
