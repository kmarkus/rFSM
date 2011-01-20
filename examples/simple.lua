--
-- Extremly simply state machine with two states
--

return rfsm.csta:new {
   getevents=function() return {1} end,
   on = rfsm.sista:new{},
   off = rfsm.sista:new{},

   rfsm.trans:new{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans:new{ src='on', tgt='off', events={ 'e_off' } },
   rfsm.trans:new{ src='initial', tgt='off' }
}
