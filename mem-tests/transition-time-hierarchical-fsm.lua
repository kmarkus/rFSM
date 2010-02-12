-- test the static memory usage behavior of a fsm

require("rtfsm")
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


function create_stopwatch()
   local start, stop, diff

   local stats = {}
   stats.dur_min = { sec=math.huge, nsec=math.huge }
   stats.dur_max = { sec=0, nsec=0 }
   stats.dur_avg = { sec=0, nsec=0 }
   stats.cnt = 0

   return function (cmd)
	     if cmd == 'start' then
		start = rtposix.gettime("MONOTONIC")
	     elseif cmd == 'stop' then
		stop = rtposix.gettime("MONOTONIC")
		diff = time.sub(stop, start)

		stats.cnt = stats.cnt+1
		stats.dur_avg = time.add(stats.dur_avg, diff)

		if time.cmp(diff, stats.dur_min) < 0 then
		   stats.dur_min = diff
		end

		if time.cmp(diff, stats.dur_max) > 0 then
		   stats.dur_max = diff
		end
	     elseif cmd == 'get_results' then
		return stats
	     elseif cmd == 'print_results' then
		io.stderr:write("max: " .. time.ts2str(stats.dur_max),
				", min: " .. time.ts2str(stats.dur_min),
				", avg: " .. time.ts2str(time.div(stats.dur_avg, stats.cnt)) .. "\n")
	     else
		assert(nil, "stopwatch: invalid command " .. cmd)
	     end
	  end
end

local sw = create_stopwatch()

local progs = {
   entry=function () 
	    sw('stop')
	    luagc.step() end,
}

-- create fsm
local fsm = rtfsm.init(fsmbuilder.composite_fsm(num_states, state_depth, progs), arg[0])
assert(fsm, "fsm init failed")
-- fsm2uml.fsm2uml(fsm, "png", "fsm_dyn_hier_test-uml.png")

-- perform full collect and stop gc
luagc.full()
luagc.full()

-- print("starting...")

for i=1,num_steps do
   sw('start')
   rtfsm.step(fsm)
   rtposix.nanosleep("REALTIME", "rel", 0, 10000)
   rtfsm.send_events(fsm, "e_trigger")
end

sw('print_results')
s = sw('get_results')
print(num_states, time.ts2us(s.dur_max))
