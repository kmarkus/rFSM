--
-- invalid state machine which creates a cycle.
-- Just for testing purposes
--


return rfsm.csta:new {
   rfsm.trans:new{ src='initial', tgt='junc1' },
   rfsm.trans:new{ src='junc1', tgt='junc2' },
   rfsm.trans:new{ src='junc2', tgt='junc1' },
   junc1 = rfsm.junc:new{},
   junc2 = rfsm.junc:new{}
}

