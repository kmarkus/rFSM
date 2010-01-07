--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("rtfsm")
require("fsmdbg")
require("utils")

local err = print
local id = 'junc_chain_with_split_test'

junc_chain_split_templ = rtfsm.csta:new{
   dummyA = rtfsm.sista:new{},
   dummyB = rtfsm.sista:new{},

   rtfsm.trans:new{ src='initial', tgt='juncA1' },
   rtfsm.trans:new{ src='juncA1', tgt='juncA2' },
   rtfsm.trans:new{ src='juncA2', tgt='dummyA', guard=function () return false end  },

   rtfsm.trans:new{ src='initial', tgt='juncB1' },
   rtfsm.trans:new{ src='juncB1', tgt='juncB2'},
   rtfsm.trans:new{ src='juncB2', tgt='dummyB' },

   juncA1 = rtfsm.junc:new{},
   juncA2 = rtfsm.junc:new{},
   juncB1 = rtfsm.junc:new{},
   juncB2 = rtfsm.junc:new{},
}

test = {
   id = 'simple_junc_split_test',
   pics = true,
   tests = { 
      {
	 descr='testing entry',
	 preact = nil,
	 events = nil,
	 expect = { root={ ['root.dummyB']='done' } }
      }
   }
}


jc = rtfsm.init(junc_chain_split_templ)

if not jc then
   print(id .. " initalization failed")
   os.exit(1)
end

if fsmdbg.test_fsm(jc, test) then os.exit(0)
else os.exit(1) end
