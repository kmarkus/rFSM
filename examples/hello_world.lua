return rfsm.composite_state {
   hello = rfsm.sista{ entry=function() print("hello") end },
   world = rfsm.simple_state{ entry=function() print("world") end },
   rfsm.transition{ src='initial', tgt='hello' },
   rfsm.transition{ src='hello', tgt='world', events={ 'e_done' } },
   rfsm.transition{ src='world', tgt='hello', events={ 'e_restart' } },
}