--
-- Extremly simply state machine with two states
--

require "rfsm"
require "rtposix"

require "rfsm_timeevent"

function gettime()
   return rtposix.clock_gettime("CLOCK_MONOTONIC") 
end

rfsm_timeevent.set_gettime_hook(gettime)

return rfsm.csta {
   -- only for rfsm-sim
   idle_hook=function() uml(); os.execute("sleep 0.5") end,

   one = rfsm.sista{},
   two = rfsm.sista{},
   three = rfsm.sista{},
   four = rfsm.sista{},
   five = rfsm.sista{},

   rfsm.trans{ src='initial', tgt='one' },
   rfsm.trans{ src='one', tgt='two', events={ 'e_after(1)' } },
   rfsm.trans{ src='two', tgt='three', events={ 'e_after(1.5)' } },
   rfsm.trans{ src='three', tgt='four', events={ 'e_after(2)' } },
   rfsm.trans{ src='four', tgt='five', events={ 'e_after(3)' } },
   rfsm.trans{ src='five', tgt='one', events={ 'e_after(4.5)' } },
}

