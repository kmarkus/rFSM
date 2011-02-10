return rfsm.composite_state:new {
   hello = rfsm.sista:new{ entry=function() print("hello") end },
   world = rfsm.simple_state:new{ entry=function() print("world") end },
   rfsm.transition:new{ src='initial', tgt='hello' },
   rfsm.transition:new{ src='hello', tgt='world', events={ 'e_done' } },
   rfsm.transition:new{ src='world', tgt='hello', events={ 'e_restart' } },
}