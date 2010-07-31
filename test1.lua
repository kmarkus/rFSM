--
-- rFSM examples
--

require("fsm2uml")
require("fsm2tree")
require("rfsm")
require("utils")

-- composite state
-- required: -
-- optional: entry, exit, states, transitions
-- disallowed: doo
local function trace(obj)
   --
end

local function true_guard()
   print("true guard")
   return true
end

local function false_guard()
   print("false guard")
   return false
end

local function test_doo()
   for i = 1,10 do
      print("doo:", i)
      coroutine.yield()
   end
end

local function idle()
   print("idle loop")
   os.execute("sleep 3")
end

dummy_state = rfsm.sista:new{ entry=trace, doo=test_doo, exit=trace }

simple_templ = rfsm.csta:new{
   on = utils.deepcopy(dummy_state),
   off = utils.deepcopy(dummy_state),
   -- _idle = idle,

   rfsm.trans:new{ src='off', tgt='on', event='e_on', effect=trace },
   rfsm.trans:new{ src='on', tgt='off', event='e_off', effect=trace },
   rfsm.trans:new{ src='initial', tgt='off', effect=trace, guard=true_guard }
}

junc_chain_templ = rfsm.csta:new{
   dummy = dummy_state,

   rfsm.trans:new{ src='initial', tgt='junc1', effect=trace, guard=true_guard },
   rfsm.trans:new{ src='junc1', tgt='junc2', effect=trace, guard=true_guard },
   rfsm.trans:new{ src='junc2', tgt='dummy', effect=trace, guard=true_guard },
   junc1 = rfsm.junc:new{},
   junc2 = rfsm.junc:new{}
}

simple = rfsm.init(simple_templ, "on_off")

-- print(simple.on._fqn)
-- print(simple.off._fqn)
-- print(simple.on == simple.off)

junc_chain = rfsm.init(junc_chain_templ, "junc_chain")

if not simple then
   print("initalization failed")
   os.exit(1)
end

fsm2uml.fsm2uml(simple, "png", "on_off-uml.png")
fsm2uml.fsm2uml(junc_chain, "png", "junc_chain-uml.png")

rfsm.step(simple)
rfsm.step(junc_chain)
