--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsmtesting")
require("utils")

-- load fsm
testfsm = rfsm.load("../examples/connector_split.lua")
testfsm.dbg = false

test = {
   id = 'simple_conn_split_test',
   pics = true,
   tests = {

      -- initial entry
      { descr='testing entry',
	expect = { leaf='root.operational', mode='done' }, },

      -- transition to hw error
      { descr='testing hw_error',
	events={"e_error", "e_hw_err" },
	expect = { leaf='root.error.hardware_err', mode='done' }, },

      -- transition back to operational
      { descr='testing back to operational',
	events={"e_error_reset" },
	expect = { leaf='root.operational', mode='done' }, },

      -- transition to sw error
      { descr='testing sw_error',
	events={"e_error", "e_sw_err" },
	expect = { leaf='root.error.software_err', mode='done' }, },
   }
}

jc = rfsm.init(testfsm)

if not jc then
   print(id .. " initalization failed")
   os.exit(1)
end

fsmtesting.print_stats(fsmtesting.test_fsm(jc, test, false))
