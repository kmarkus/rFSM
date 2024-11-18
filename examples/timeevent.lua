--
-- Simple timeevent demo
--

local rfsm = require("rfsm")
local timeevent = require("rfsm.timeevent")

local e_after = timeevent.e_after

local function gettime() return os.time() * 1000*1000*1000 end

timeevent.set_gettime_hook(gettime)

return rfsm.csta {
   dbg=true,

   one = rfsm.sista{},
   two = rfsm.sista{},
   three = rfsm.sista{},
   four = rfsm.sista{},
   five = rfsm.sista{},

   rfsm.trans{ src='initial', tgt='one' },
   rfsm.trans{ src='one', tgt='two', events={ e_after(0.1) } },
   rfsm.trans{ src='two', tgt='three', events={ e_after(0.2) } },
   rfsm.trans{ src='three', tgt='four', events={ e_after(0.3) } },
   rfsm.trans{ src='four', tgt='five', events={ e_after(0.4) } },
   rfsm.trans{ src='five', tgt='one', events={ e_after(1) } },
}
