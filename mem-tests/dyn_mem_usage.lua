-- test the static memory usage behavior of a fsm

package.path = package.path .. ';../?.lua'
package.path = package.path .. ';/home/mk/prog/lua/modules/?.lua'
package.cpath = package.cpath .. ';/home/mk/prog/lua/modules/?.so;'

require("rtfsm")
require("time")
require("luagc")
require("fsm2uml")
require("utils")
require("fsmbuilder")
require("rtposix")


-- function () print(luagc.gcstat_tostring(luagc.timed_gc("collect"))) end
local progs = {
   entry=luagc.create_bench("step"),
--   doo = function (fsm, state, type)
-- 	    rtposix.nanosleep("REALTIME", "rel", 0, 1)
-- 	    -- print("sending e_trigger")
-- 	    -- rtfsm.send_events(fsm, "e_trigger")
-- 	 end
}

-- create fsm
local fsm = rtfsm.init(fsmbuilder.flat_chain_fsm(10, progs), "fsm_dyn_test")
assert(fsm, "fsm init failed")
fsm2uml.fsm2uml(fsm, "png", "fsm_dyn_test-uml.png")

-- perform full collect and stop gc
luagc.full()

for i=1,100000 do
   rtfsm.step(fsm)
   rtfsm.send_events(fsm, "e_trigger")
end

progs.entry("print_results")
