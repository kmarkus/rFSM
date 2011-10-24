--- Simple example to illustrate multiple levels of FSM composition.
-- globals that are visible at the top level are visible at nested
-- levels too.

require "rfsm"
require "fsmpp"

--- This (global) function will be visible in all sub-fsm!
function foo(a,b,c)
   print("Howdy: ", a,b,c)
end

fsm=rfsm.init(rfsm.load('root.lua'))
fsm.dbg=fsmpp.gen_dbgcolor()

rfsm.step(fsm, 10)



