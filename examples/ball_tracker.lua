--
-- The ball tracking example
--

local rfsm = require("rfsm")
local state, conn, trans = rfsm.state, rfsm.conn, rfsm.trans

return state {
   tracked = state{
      following = state{ },
      hitting = state{ },
      trans{ src='initial', tgt='following' },
      trans{ src='following', tgt='hitting', events={ 'e_cmd_hit' } },
      trans{ src='hitting', tgt='following', events={ 'e_done' } }
   },

   untracked = state{},
   calibration = state{},

   trans{ src='initial', tgt='untracked' },
   trans{ src='untracked', tgt='calibration', events={'e_cmd_cali' } },
   trans{ src='calibration', tgt='untracked', events={'e_done' } },

   trans{ src='untracked', tgt='tracked', events={'e_tracked' } },
   trans{ src='tracked', tgt='untracked', events={'e_untracked' } },
   trans{ src='tracked.following', tgt='calibration', events={'e_cmd_cali' } },
}
