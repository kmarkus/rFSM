

return rfsm.csta{
   off=rfsm.sista{},
   on=rfsm.load("subfsm.lua"),

   rfsm.trans{ src='initial', tgt='off' },
   rfsm.trans{ src='off', tgt='on', events={'e_done'} }
}
