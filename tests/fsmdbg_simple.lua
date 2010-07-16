--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("rtfsm")
require("fsmdbg")

simple_templ = rtfsm.csta:new{

   _idle=function () os.execute("sleep 0.1") end,

   on = rtfsm.sista:new{},
   off = rtfsm.sista:new{},

   rtfsm.trans:new{ src='off', tgt='on', events={ 'e_on' } },
   rtfsm.trans:new{ src='on', tgt='off', events={ 'e_off' } },
   rtfsm.trans:new{ src='initial', tgt='off' }
}



fsm = rtfsm.init(simple_templ, "simple_test")
-- enable debugging on fsm
fsmdbg.enable(fsm)
rtfsm.step(fsm)
