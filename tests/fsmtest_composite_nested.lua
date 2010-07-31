--
-- composite tests transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsm2tree")
require("fsmtesting")
require("utils")

local function printer_gen(s)
   return function (...) print(s, unpack(arg)) end
end

local function puts(...)
   print(arg)
end

local function safe_doo()
   for i = 1,3 do
      print("waiting in safe mode:", i)
      os.execute("sleep 0.3")
      coroutine.yield()
   end
end

csta_tmpl = rfsm.csta:new {
   err = printer_gen("ERR:"),
   warn = printer_gen("WARN:"),
   info = printer_gen("INFO:"),
   dbg = printer_gen("DBG:"),

   operational = rfsm.csta:new{
      approaching = rfsm.sista:new{ entry=puts("entering approaching state"), exit=puts("exiting approaching state") },
      in_contact = rfsm.sista:new{ entry=puts("contact established"), exit=puts("contact lost") },

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
	 expect = { root={ ['root.safe']='done' } }
      }, {
	 descr='testing transition to operational',
	 events = { 'e_range_clear' },
	 expect = { root={ ['operational'] = { ['root.operational.approaching']='done'} } }
      }, {
	 descr='testing transition to in_contact',
	 events = { 'e_contact_made' },
	 expect = { root={ ['operational'] = { ['root.operational.in_contact']='done'} } }
      }, {
	 descr='testing transition to safe',
	 events = { 'e_close_object' },
	 expect = { root={ ['root.safe'] = 'done'} },
      }
   }
}


fsm = rfsm.init(csta_tmpl, "composite_nested_tests")

if fsmtesting.test_fsm(fsm, test) then os.exit(0)
else os.exit(1) end
