--
-- composite tests transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("rfsm2tree")
require("rfsm_testing")
require("rfsmpp")
require("utils")

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

testfsm = rfsm.load("../examples/composite_nested.lua")
testfsm.dbg = false

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


fsm = rfsm.init(testfsm, "composite_nested_tests")

rfsm_testing.print_stats(rfsm_testing.test_fsm(fsm, test, false))
