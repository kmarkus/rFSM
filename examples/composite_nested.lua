require ("fsmpp")

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

return rfsm.csta:new {

   dbg = false,

   operational = rfsm.csta:new{

      approaching = rfsm.sista:new{
	 entry=puts("entering approaching state"),
	 exit=puts("exiting approaching state")
      },

      in_contact = rfsm.sista:new{
	 entry=puts("contact established"),
	 exit=puts("contact lost")
      },

      rfsm.trans:new{ src='initial', tgt='approaching' },
      rfsm.trans:new{ src='approaching', tgt='in_contact', events={ 'e_contact_made' } },
      rfsm.trans:new{ src='in_contact', tgt='approaching', events={ 'e_contact_lost' } },
   },

   safe = rfsm.sista:new{ entry=puts("entering safe mode"),
			  doo=safe_doo,
			  exit=puts("exiting safe mode") },

   rfsm.trans:new{ src='initial', tgt='safe' },
   rfsm.trans:new{ src='safe', tgt='operational', events={ 'e_range_clear' } },
   rfsm.trans:new{ src='operational', tgt='safe', events={ 'e_close_object' } },
}
