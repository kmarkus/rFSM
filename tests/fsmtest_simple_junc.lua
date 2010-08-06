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
local id = 'junc_chain_test'

junc_test_templ = rfsm.csta:new{

   dbg = fsmpp.dbgcolor,

   dummy = rfsm.sista:new{},
   junc1 = rfsm.junc:new{},
   junc2 = rfsm.junc:new{},

   rfsm.trans:new{ src='initial', tgt='junc1' },
   rfsm.trans:new{ src='junc1', tgt='junc2' },
   rfsm.trans:new{ src='junc2', tgt='dummy' }
}


test = {
   id = 'simple_junc_test',
   pics = true,
   tests = {
      {
	 descr='testing entry',
	 preact = nil,
	 events = nil,
	 expect = { root={ ['root.dummy']='done' } }
      }
   }
}


jc = rfsm.init(junc_test_templ)

if not jc then
   err(id .. " initalization failed")
   os.exit(1)
end

if fsmtesting.test_fsm(jc, test, true) then os.exit(0)
else os.exit(1) end
