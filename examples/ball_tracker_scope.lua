--
-- The ball tracking example
--

local rfsm = require("rfsm")

return rfsm.csta {
   tracked = rfsm.csta{ 
      following = rfsm.sista{ },
      hitting = rfsm.sista{ },
      rfsm.trans{ src='initial', tgt='following' },
      rfsm.trans{ src='following', tgt='hitting', pn=10, events={ 't6' } },
      rfsm.trans{ src='hitting', tgt='following', events={ 't7' } }
   },
   
   untracked = rfsm.sista{},
   calibration = rfsm.sista{},

   rfsm.trans{ src='initial', tgt='untracked' },
   rfsm.trans{ src='untracked', tgt='calibration', events={'t1' } },
   rfsm.trans{ src='calibration', tgt='untracked', events={'t2' } },
   
   rfsm.trans{ src='untracked', tgt='tracked', events={'t3' } },
   rfsm.trans{ src='tracked', tgt='untracked', events={'t4' } },
   rfsm.trans{ src='tracked.following', tgt='calibration', events={'t5' } },
}

