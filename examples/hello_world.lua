local rfsm = require("rfsm")

return rfsm.state {

   hello = rfsm.state{ entry=function() print("hello") end },
   world = rfsm.state{ entry=function() print("world") end },

   rfsm.transition { src='initial', tgt='hello' },
   rfsm.transition { src='hello', tgt='world', events={ 'e_done' } },
   rfsm.transition { src='world', tgt='hello', events={ 'e_restart' } },
}
