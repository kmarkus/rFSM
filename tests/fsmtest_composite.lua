--
-- composite tests transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsm2tree")
require("fsmtesting")
require("fsmpp")
require("utils")

local function test_doo()
   for i = 1,5 do
      print("doo:", i)
      os.execute("sleep 0.1")
      coroutine.yield()
   end
end

csta_tmpl = rfsm.composite_state:new{
   dbg = false, -- fsmpp.dbgcolor,
   warn = fsmpp.dbgcolor,
   err = fsmpp.dbgcolor,

   on = rfsm.simple_state:new{ doo=test_doo },
   off = rfsm.simple_state:new{},

   rfsm.transition:new{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.transition:new{ src='on', tgt='off', events={ 'e_off' } },
   rfsm.transition:new{ src='initial', tgt='off' }
}


local test = {
   id = 'composite_tests',
   pics = true,
   tests = {
      {
	 descr='testing entry',
	 preact = nil,
	 events = nil,
	 expect = { leaf='root.off', mode='done' },
      }, {
	 descr='testing transition to on',
	 events = { 'e_on' },
	 expect = { leaf='root.on', mode='done'},
      }
   }
}

fsm = rfsm.init(csta_tmpl, "composite_tests")

fsmtesting.print_stats(fsmtesting.test_fsm(fsm, test, false))

