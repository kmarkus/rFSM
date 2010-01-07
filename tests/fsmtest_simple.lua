--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("rtfsm")
require("fsm2uml")
require("fsm2tree")
require("fsmdbg")
require("utils")

local function printer_gen(s)
   return function (...) print(s, unpack(arg)) end
end

simple_templ = rtfsm.csta:new{
   err = printer_gen("ERR:"),
   warn = printer_gen("WARN:"),
   info = printer_gen("INFO:"),
   -- dbg = printer_gen("DBG:"),

   on = rtfsm.sista:new{},
   off = rtfsm.sista:new{},

   rtfsm.trans:new{ src='off', tgt='on', event='e_on' },
   rtfsm.trans:new{ src='on', tgt='off', event='e_off' },
   rtfsm.trans:new{ src='initial', tgt='off' }
}


local test = {
   id = 'simple_tests',
   pics = true,
   tests = {
      {
	 descr='testing entry',
	 preact = nil,
	 events = nil,
	 expect = { root={ ['root.off']='active' } }
      }, {
	 descr='testing transition to on',
	 events = { 'e_on' },
	 expect = { root={ ['root.on']='active'} }
      }, {
	 descr='testing transition back to off',
	 events = { 'e_off' },
	 expect = { root={ ['root.off']='active'} }
      }, {
	 descr='doing nothing',
	 expect = { root={ ['root.off']='done'} }
      }
   }
}

fsm = rtfsm.init(simple_templ, "simple_test")

if fsmdbg.test_fsm(fsm, test) then os.exit(0)
else os.exit(1) end
