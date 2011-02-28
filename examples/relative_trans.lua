---
-- This simple example illustrates relative transitions
--
-- The transitions between on and off are not added locally, but
-- "layered" on from the parent state using the relative, leading dot
-- syntax.
--

local sista, csta, trans, conn = rfsm.sista, rfsm.csta, rfsm.trans, rfsm.conn

return csta:new {
   operational = csta:new {
      on = sista:new {},
      off = sista:new {},
      trans:new{ src='initial', tgt='off' },
   },

   trans:new{ src='initial', tgt='operational' },
   -- not allowed, initial must always be local:
   -- trans:new{ src='.operational.initial', tgt='.operational.off' },
   trans:new{ src='.operational.on', tgt='.operational.off', events={'e_off'} },
   trans:new{ src='.operational.off', tgt='.operational.on', events={'e_on'} },
}