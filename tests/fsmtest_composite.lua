--
-- composite tests transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsm2tree")
require("fsmtesting")
require("fsmpprint")
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

csta_tmpl = rfsm.csta:new{
   dbg = fsmpprint.dbgcolor,

   on = rfsm.sista:new{ doo=test_doo },
   off = rfsm.sista:new{},

   rfsm.trans:new{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans:new{ src='on', tgt='off', events={ 'e_off' } },
   rfsm.trans:new{ src='initial', tgt='off' }
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

fsm = rfsm.init(csta_tmpl, "composite_tests")

if fsmtesting.test_fsm(fsm, test, true) then os.exit(0)
else os.exit(1) end
