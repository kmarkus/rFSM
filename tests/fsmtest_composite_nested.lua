--
-- composite tests transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsm2tree")
require("fsmtesting")
require("fsmpp")
require("utils")

local function puts(...)
   return function () print(unpack(arg)) end
end

local function safe_doo()
   for i = 1,3 do
      print("waiting in safe mode:", i)
      os.execute("sleep 0.3")
      coroutine.yield()
   end
end

csta_tmpl = rfsm.csta:new {
   dbg = false, --fsmpp.dbgcolor,
   -- dbg = fsmpp.gen_dbgcolor({["STATE_ENTER"]=true, ["STATE_EXIT"]=true,
   -- 				 ["HIBERNATING"]=true, ["EXEC_PATH"]=true,
   -- 				 ["EFFECT"]=true, ["DOO"]=true, ["CHECKING"]=true}),

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


local test = {
   id = 'composite_nested_tests',
   pics = true,
   tests = {
      {
	 descr='testing entry',
	 preact = nil,
	 events = nil,
	 expect = { leaf='root.safe', mode='done' },
      }, {
	 descr='testing transition to operational',
	 events = { 'e_range_clear' },
	 expect = { leaf='root.operational.approaching', mode='done'},
      }, {
	 descr='testing transition to in_contact',
	 events = { 'e_contact_made' },
	 expect = { leaf='root.operational.in_contact', mode='done'},
      }, {
	 descr='testing transition to safe',
	 events = { 'e_close_object' },
	 expect = { leaf='root.safe', mode = 'done'},
      }
   }
}


fsm = rfsm.init(csta_tmpl, "composite_nested_tests")

fsmtesting.print_stats(fsmtesting.test_fsm(fsm, test, false))
