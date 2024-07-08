local rfsm = require("rfsm")
local unpack = rawget(_G, "unpack") or table.unpack -- unpack is a global function for Lua 5.1, otherwise use table.unpack

local function puts(...)
   return function () print(unpack(arg)) end
end

local function safe_doo()
   for i = 1,3 do
      print("waiting in safe mode:", i)
      os.execute("sleep 0.3")
      rfsm.yield()
   end
end

return rfsm.csta {

   dbg = false,

   operational = rfsm.csta{

      approaching = rfsm.sista{
	 entry=puts("entering approaching state"),
	 exit=puts("exiting approaching state")
      },

      in_contact = rfsm.sista{
	 entry=puts("contact established"),
	 exit=puts("contact lost")
      },

      rfsm.trans{ src='initial', tgt='approaching' },
      rfsm.trans{ src='approaching', tgt='in_contact', events={ 'e_contact_made' } },
      rfsm.trans{ src='in_contact', tgt='approaching', events={ 'e_contact_lost' } },
   },

   safe = rfsm.sista{ entry=puts("entering safe mode"),
			  doo=safe_doo,
			  exit=puts("exiting safe mode") },

   rfsm.trans{ src='initial', tgt='safe' },
   rfsm.trans{ src='safe', tgt='operational', events={ 'e_range_clear' } },
   rfsm.trans{ src='operational', tgt='safe', events={ 'e_close_object' } },
}
