
local state, trans, conn = rfsm.state, rfsm.trans, rfsm.conn

return state {
   on = state{},
   off = state{},

   trans{src='initial', tgt='off'},
   trans{src='on', tgt='off', events={'e_on'} },
   trans{src='off', tgt='on', events={'e_off'} },
}