--
-- composite tests transitions
--

package.path = package.path .. ';../?.lua'

require("rtfsm")
require("fsm2tree")
require("fsmtesting")
require("utils")

local function printer_gen(s)
   return function (...) print(s, unpack(arg)) end
end

local function test_doo()
   for i = 1,5 do
      print("doo:", i)
      os.execute("sleep 1")
      coroutine.yield()
   end
end

csta_tmpl = rtfsm.csta:new{
   err = printer_gen(""),
   warn = printer_gen(""),
   info = printer_gen(""),
   dbg = printer_gen(""),

   on = rtfsm.sista:new{ doo=test_doo },
   off = rtfsm.sista:new{},

   rtfsm.trans:new{ src='off', tgt='on', events={ 'e_on' } },
   rtfsm.trans:new{ src='on', tgt='off', events={ 'e_off' } },
   rtfsm.trans:new{ src='initial', tgt='off' }
}


local test = {
   id = 'composite_tests',
   pics = true,
   tests = {
      {
	 descr='testing entry',
	 preact = nil,
	 events = nil,
	 expect = { root={ ['root.off']='done' } }
      }, {
	 descr='testing transition to on',
	 events = { 'e_on' },
	 expect = { root={ ['root.on']='done'} }
      }
   }
}

fsm = rtfsm.init(csta_tmpl, "composite_tests")

if fsmtesting.test_fsm(fsm, test) then os.exit(0)
else os.exit(1) end
