---
-- This simple example illustrates relative transitions
--
-- The transitions between on and off are not added locally, but
-- "layered" on from the parent state using the relative, leading dot
-- syntax.
--
local rfsm = require("rfsm")

local sista, csta, trans, conn = rfsm.sista, rfsm.csta, rfsm.trans, rfsm.conn

return csta {
   operational = csta {
      on = sista {},
      off = sista {},
      trans{ src='initial', tgt='off' },
   },

   trans{ src='initial', tgt='operational' },
   -- not allowed, initial must always be local:
   -- trans{ src='.operational.initial', tgt='.operational.off' },
   trans{ src='.operational.on', tgt='.operational.off', events={'e_off'} },
   trans{ src='.operational.off', tgt='.operational.on', events={'e_on'} },
}
