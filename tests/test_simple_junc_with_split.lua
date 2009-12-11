--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("fsm2uml")
require("fsm2tree")
require("rtfsm")
require("utils")

local err = print
local id = 'junc_chain_with_split_test'

junc_chain_templ = rtfsm.csta:new{
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

jc = rtfsm.init(junc_chain_templ, id)

if not jc then
   err(id .. " initalization failed")
   os.exit(1)
end

fsm2uml.fsm2uml(jc, "png", id .. "before-uml.png")
rtfsm.step(jc)
fsm2uml.fsm2uml(jc, "png", id .. "after-uml.png")
