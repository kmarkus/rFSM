--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsmtesting")
require("utils")

local err = print
local id = 'junc_chain_with_split_test'

junc_chain_split_templ = rfsm.csta:new{
   dummyA = rfsm.sista:new{},
   dummyB = rfsm.sista:new{},

   rfsm.trans:new{ src='initial', tgt='juncA1' },
   rfsm.trans:new{ src='juncA1', tgt='juncA2' },
   rfsm.trans:new{ src='juncA2', tgt='dummyA', guard=function () return false end  },

   rfsm.trans:new{ src='initial', tgt='juncB1' },
   rfsm.trans:new{ src='juncB1', tgt='juncB2'},
   rfsm.trans:new{ src='juncB2', tgt='dummyB' },

   juncA1 = rfsm.junc:new{},
   juncA2 = rfsm.junc:new{},
   juncB1 = rfsm.junc:new{},
   juncB2 = rfsm.junc:new{},
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


jc = rfsm.init(junc_chain_split_templ)

if not jc then
   print(id .. " initalization failed")
   os.exit(1)
end

if fsmtesting.test_fsm(jc, test) then os.exit(0)
else os.exit(1) end
