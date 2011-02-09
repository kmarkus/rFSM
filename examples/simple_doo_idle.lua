-- simple sample state machine which defines an idle doo

return  rfsm.csta:new{

   dbg = fsmpp.gen_dbgcolor("fsmtest_simple"),

   on = rfsm.sista:new{},
   off = rfsm.sista:new{},
   busy = rfsm.sista:new{ doo=function() coroutine.yield(true) end },

   rfsm.trans:new{ src='initial', tgt='off' },
   rfsm.trans:new{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans:new{ src='on', tgt='off', events={ 'e_off' } },
   rfsm.trans:new{ src='off', tgt='busy', events={ 'e_busy' } },
   rfsm.trans:new{ src='busy', tgt='off', events={ 'e_done' } },
}
