--
-- invalid state machine which creates a cycle.
-- Just for testing purposes
--
local rfsm = require("rfsm")

return rfsm.csta {
   rfsm.trans{ src='initial', tgt='conn1' },
   rfsm.trans{ src='conn1', tgt='conn2' },
   rfsm.trans{ src='conn2', tgt='conn1' },
   conn1 = rfsm.conn{},
   conn2 = rfsm.conn{}
}

