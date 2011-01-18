--
-- The ball tracking example
--

return rfsm.csta:new {
   tracked = rfsm.csta:new{ 
      following = rfsm.sista:new{ },
      hitting = rfsm.sista:new{ },
      rfsm.trans:new{ src='initial', tgt='following' },
      rfsm.trans:new{ src='following', tgt='hitting', pn=10, events={ 't6' } },
      rfsm.trans:new{ src='hitting', tgt='following', events={ 't7' } }
   },
   
   untracked = rfsm.sista:new{},
   calibration = rfsm.sista:new{},

   rfsm.trans:new{ src='initial', tgt='untracked' },
   rfsm.trans:new{ src='untracked', tgt='calibration', events={'t1' } },
   rfsm.trans:new{ src='calibration', tgt='untracked', events={'t2' } },
   
   rfsm.trans:new{ src='untracked', tgt='tracked', events={'t3' } },
   rfsm.trans:new{ src='tracked', tgt='untracked', events={'t4' } },
   rfsm.trans:new{ src='tracked.following', tgt='calibration', events={'t5' } },
}

