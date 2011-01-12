--
-- test simple transitions
--

package.path = package.path .. ';../?.lua'

require("rfsm")
require("fsmdbg")

simple_templ = rfsm.csta:new{

   idle_hook=function () os.execute("sleep 0.1") end,

   on = rfsm.sista:new{},
   off = rfsm.sista:new{},

   rfsm.trans:new{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans:new{ src='on', tgt='off', events={ 'e_off' } },
   rfsm.trans:new{ src='initial', tgt='off' }
}



fsm = rfsm.init(simple_templ, "simple_test")
-- enable debugging on fsm
fsmdbg.enable(fsm)
rfsm.step(fsm)
