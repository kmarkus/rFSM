--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("fsm2uml")
require("fsm2tree")
require("rtfsm")
require("utils")

local err = print
local id = 'junc_chain_test'

junc_chain_templ = rtfsm.csta:new{
   dummy = rtfsm.sista:new{},

   rtfsm.trans:new{ src='initial', tgt='junc1' },
   rtfsm.trans:new{ src='junc1', tgt='junc2' },
   rtfsm.trans:new{ src='junc2', tgt='dummy' },

   junc1 = rtfsm.junc:new{},
   junc2 = rtfsm.junc:new{}
}

jc = rtfsm.init(junc_chain_templ, id)

if not jc then
   err(id .. " initalization failed")
   os.exit(1)
end

fsm2uml.fsm2uml(jc, "png", id .. "before-uml.png")
rtfsm.step(jc)
fsm2uml.fsm2uml(jc, "png", id .. "after-uml.png")
