-- test the static memory usage behavior of a fsm

require("rfsm")
require("time")
require("luagc")
--require("fsm2uml")
require("utils")
require("fsmbuilder")
require("rtposix")

assert(#arg == 3, "wrong numer of args: <num_steps> <num_states> <state_depth>")

rtposix.mlockall("MCL_BOTH")
rtposix.sched_setscheduler(0, "SCHED_FIFO", 99)

local num_steps = tonumber(arg[1])
local num_states = tonumber(arg[2])
local state_depth = tonumber(arg[3])

-- function () print(luagc.gcstat_tostring(luagc.timed_gc("collect"))) end

local progs = {
   entry=luagc.create_bench("step"),
}

-- create fsm
local fsm = rfsm.init(fsmbuilder.composite_fsm(num_states, state_depth, progs), arg[0])
assert(fsm, "fsm init failed")
-- fsm2uml.fsm2uml(fsm, "png", "fsm_dyn_hier_test-uml.png")

-- perform full collect and stop gc
luagc.full()
luagc.full()

-- print("starting...")

for i=1,num_steps do
   rfsm.step(fsm)
   rfsm.send_events(fsm, "e_trigger")
   rtposix.nanosleep("REALTIME", "rel", 0, 10000)
end

progs.entry("print_results")
s = progs.entry("get_results")
print(num_states, time.ts2us(s.dur_max))
