--
-- test simple transitions
--

require ('luarocks.loader')
require('std')

package.path = package.path .. ';../?.lua'

require("fsm2uml")
require("fsm2tree")
require("rtfsm")
require("utils")

local err = print
local id = 'simple_on_off_test'

simple_templ = rtfsm.csta:new{
   on = rtfsm.sista:new{},
   off = rtfsm.sista:new{},

   rtfsm.trans:new{ src='off', tgt='on', event='e_on' },
   rtfsm.trans:new{ src='on', tgt='off', event='e_off' },
   rtfsm.trans:new{ src='initial', tgt='off' }
}

simple = rtfsm.init(simple_templ, id)

if not simple then
   err(id .. " initalization failed")
   os.exit(1)
end

fsm2uml.fsm2uml(simple, "png", id .. "prestart" .. ".png")
print("act_conf prestart:", rtfsm.dbg.get_act_conf(simple))

rtfsm.step(simple)
fsm2uml.fsm2uml(simple, "png", id .. "after-first-step" .. ".png")
print("act_conf after first step:", rtfsm.dbg.get_act_conf(simple))

rtfsm.send_events(simple, 'e_on')
rtfsm.step(simple)
fsm2uml.fsm2uml(simple, "png", id .. "after-second-step" .. ".png")
print("act_conf after second step:", rtfsm.dbg.get_act_conf(simple))

