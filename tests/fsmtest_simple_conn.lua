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

local err = print
local id = 'conn_chain_test'

conn_test_templ = rfsm.csta:new{

   dbg = false, -- fsmpp.dbgcolor,

   dummy = rfsm.sista:new{},
   conn1 = rfsm.conn:new{},
   conn2 = rfsm.conn:new{},

   rfsm.trans:new{ src='initial', tgt='conn1' },
   rfsm.trans:new{ src='conn1', tgt='conn2' },
   rfsm.trans:new{ src='conn2', tgt='dummy' }
}


test = {
   id = 'simple_conn_test',
   pics = true,
   tests = {
      {
	 descr='testing entry',
	 preact = nil,
	 events = nil,
	 expect = { leaf='root.dummy', mode='done' },
      }
   }
}


jc = rfsm.init(conn_test_templ)

if not jc then
   err(id .. " initalization failed")
   os.exit(1)
end

fsmtesting.print_stats(fsmtesting.test_fsm(jc, test, false))
