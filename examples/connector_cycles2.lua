-- Bounded cyclic composite transitions using connectors. This one is
-- just to prove that cycles are supported by the rFSM model and
-- reference implementation. The key point is that the maximum cycles
-- that are actually executed must be limited somehow, as for example
-- by the guard here.
--
-- Most likely doing this is not a good idea for real systems.
--
local rfsm = require("rfsm")

max=50
cnt=0
function guardA() cnt=cnt+1; return cnt<max; end
function inv_guardA() return cnt>=max end

return rfsm.csta {
   rfsm.trans{ src='initial', tgt='conn1' },
   rfsm.trans{ src='conn1', tgt='conn2', guard=guardA },
   rfsm.trans{ src='conn2', tgt='conn1', guard=guardA },
   rfsm.trans{ src='conn2', tgt='foo', guard=inv_guardA },
   rfsm.trans{ src='foo', tgt='conn1', 
	       guard=guardA, 
	       effect=function() print("back into the cycles!") end,
	       events={"e_restart"},
	    },
   conn1 = rfsm.conn{},
   conn2 = rfsm.conn{},
   foo=rfsm.state{ entry=function() cnt=0 end },
}

