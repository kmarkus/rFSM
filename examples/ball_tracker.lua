--
-- The ball tracking example
--

return rfsm.csta:new {
   tracked = rfsm.csta:new{ 
      following = rfsm.sista:new{ },
      hitting = rfsm.sista:new{ },
      rfsm.trans:new{ src='initial', tgt='following' },
      rfsm.trans:new{ src='following', tgt='hitting', events={ 'e_cmd_hit' } },
      rfsm.trans:new{ src='hitting', tgt='following', events={ 'e_done' } }
   },
   
   untracked = rfsm.sista:new{},
   calibration = rfsm.sista:new{},

   rfsm.trans:new{ src='initial', tgt='untracked' },
   rfsm.trans:new{ src='untracked', tgt='calibration', events={'e_cmd_cali' } },
   rfsm.trans:new{ src='calibration', tgt='untracked', events={'e_done' } },
   
   rfsm.trans:new{ src='untracked', tgt='tracked', events={'e_tracked' } },
   rfsm.trans:new{ src='tracked', tgt='untracked', events={'e_untracked' } },
   rfsm.trans:new{ src='tracked.following', tgt='calibration', events={'e_cmd_cali' } },
}

