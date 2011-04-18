--
-- Extremly simply state machine with two states
--

return rfsm.csta {
   getevents=function() return {1} end,
   on = rfsm.sista{},
   off = rfsm.sista{},

   rfsm.trans{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans{ src='on', tgt='off', events={ 'e_off' } },
   rfsm.trans{ src='initial', tgt='off' }
}
