--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("fsm2uml")
require("fsm2tree")
require("rtfsm")
require("fsmtesting")
require("utils")

local err = print
local id = 'junc_chain_test'

junc_test_templ = rtfsm.csta:new{
   dummy = rtfsm.sista:new{},
   junc1 = rtfsm.junc:new{},
   junc2 = rtfsm.junc:new{},

   rtfsm.trans:new{ src='initial', tgt='junc1' },
   rtfsm.trans:new{ src='junc1', tgt='junc2' },
   rtfsm.trans:new{ src='junc2', tgt='dummy' }
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


jc = rtfsm.init(junc_test_templ)

if not jc then
   err(id .. " initalization failed")
   os.exit(1)
end

if fsmtesting.test_fsm(jc, test) then os.exit(0)
else os.exit(1) end

