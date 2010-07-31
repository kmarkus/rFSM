--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsm2tree")
require("fsmtesting")
require("utils")

local function printer_gen(s)
   return function (...) print(s, unpack(arg)) end
end

simple_templ = rfsm.csta:new{
   err = printer_gen("ERR:"),
   warn = printer_gen("WARN:"),
   info = printer_gen("INFO:"),
   dbg = printer_gen("DBG:"),

   on = rfsm.sista:new{},
   off = rfsm.sista:new{},

   rfsm.trans:new{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans:new{ src='on', tgt='off', events={ 'e_off' } },
   rfsm.trans:new{ src='initial', tgt='off' }
}


local test = {
   id = 'simple_tests',
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
      }, {
	 descr='testing transition back to off',
	 events = { 'e_off' },
	 expect = { root={ ['root.off']='done'} }
      }, {
	 descr='doing nothing',
	 expect = { root={ ['root.off']='done'} }
      }
   }
}

fsm = rfsm.init(simple_templ, "simple_test")

if fsmtesting.test_fsm(fsm, test) then os.exit(0)
else os.exit(1) end
