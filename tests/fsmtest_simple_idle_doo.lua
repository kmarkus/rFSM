--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("rfsm2tree")
require("rfsm_testing")
require("utils")
require("rfsmpp")

local testfsm = rfsm.load("../examples/simple_doo_idle.lua")

local test = {
   id = 'simple_tests',
   pics = false,
   tests = {
      {
	 descr='testing entry',
	 preact = nil, -- { node=fqn, mode="done" }
	 events = nil,
	 expect = { leaf='root.off', mode='done' },
      }, {
	 descr='testing transition to on',
	 events = { 'e_on' },
	 expect = { leaf='root.on', mode='done'},
      }, {
	 descr='testing transition back to off',
	 events = { 'e_off' },
	 expect = { leaf='root.off', mode='done'},
      }, {
	 descr='testing to busy',
	 events = { 'e_busy' },
	 expect = { leaf='root.busy', mode='active'},
      }, {
	 descr='doing nothing',
	 expect = { leaf='root.off', mode='done'}
      }
   }
}


fsm = rfsm.init(testfsm, "simple_test")
rfsm_testing.print_stats(rfsm_testing.test_fsm(fsm, test, false))
