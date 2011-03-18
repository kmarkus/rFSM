--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("fsm2uml")
require("fsm2tree")
require("rfsm")
require("fsmtesting")
require("fsmpp")
require("utils")

testfsm = rfsm.load("../examples/connector_simple.lua")
testfsm.dbg=false

test = {
   id = 'simple_conn_test',
   pics = true,
   tests = {
      { descr = 'testing entry',
	preact = nil,
	events = nil,
	expect = { leaf='root.start', mode='done' }, },

      { descr = 'testing failed connector transition 1',
	preact = nil,
	events = { "some_event" } ,
	expect = { leaf='root.start', mode='done' }, },

      { descr = 'testing failed connector transition 2',
	preact = nil,
	events = { "eventA" },
	expect = { leaf='root.start', mode='done' }, },

      { descr = 'testing successfull connector transition',
	preact = nil,
	events = { "eventA", "eventB" },
	expect = { leaf='root.end', mode='done' }, },
   }
}

jc = rfsm.init(testfsm)

if not jc then
   err(test.id .. " initalization failed")
   os.exit(1)
end

fsmtesting.print_stats(fsmtesting.test_fsm(jc, test, true))
