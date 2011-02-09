--
-- invalid state machine which creates a cycle.
-- Just for testing purposes
--


return rfsm.csta:new {
   rfsm.trans:new{ src='initial', tgt='conn1' },
   rfsm.trans:new{ src='conn1', tgt='conn2' },
   rfsm.trans:new{ src='conn2', tgt='conn1' },
   conn1 = rfsm.conn:new{},
   conn2 = rfsm.conn:new{}
}

