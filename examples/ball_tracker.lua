--
-- The ball tracking example
--

return rfsm.csta {
   tracked = rfsm.csta{ 
      following = rfsm.sista{ },
      hitting = rfsm.sista{ },
      rfsm.trans{ src='initial', tgt='following' },
      rfsm.trans{ src='following', tgt='hitting', events={ 'e_cmd_hit' } },
      rfsm.trans{ src='hitting', tgt='following', events={ 'e_done' } }
   },
   
   untracked = rfsm.sista{},
   calibration = rfsm.sista{},

   rfsm.trans{ src='initial', tgt='untracked' },
   rfsm.trans{ src='untracked', tgt='calibration', events={'e_cmd_cali' } },
   rfsm.trans{ src='calibration', tgt='untracked', events={'e_done' } },
   
   rfsm.trans{ src='untracked', tgt='tracked', events={'e_tracked' } },
   rfsm.trans{ src='tracked', tgt='untracked', events={'e_untracked' } },
   rfsm.trans{ src='tracked.following', tgt='calibration', events={'e_cmd_cali' } },
}

