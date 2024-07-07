local rfsm = require("rfsm")

return rfsm.csta {
   idle = rfsm.sista{},
   
   busy = rfsm.csta {
      one = rfsm.sista{},
      cexit = rfsm.conn{},
      rfsm.trans{ src='initial', tgt='one'},
      rfsm.trans{ src='one', tgt='cexit', events={ 'e_done' } },
   },

   recharging = rfsm.sista{},

   rfsm.trans { src='initial', tgt='idle' },
   rfsm.trans { src='idle', tgt='busy', events={ 'e_start'} },
   rfsm.trans { src='busy.cexit', tgt='recharging', events={} },
}
