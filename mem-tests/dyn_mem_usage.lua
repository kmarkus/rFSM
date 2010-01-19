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


function create_bench(type)

   local stats = {}
   stats.dur_min = { sec=math.huge, nsec=math.huge }
   stats.dur_max = { sec=0, nsec=0 }
   stats.dur_avg = { sec=0, nsec=0 }
   stats.cnt = 0

   return function (cmd)
	     if cmd == 'get_results' then
		return stats
	     elseif cmd == 'print_results' then
		io.stderr:write("max: " .. time.ts2str(stats.dur_max),
				", min: " .. time.ts2str(stats.dur_min),
				", avg: " .. time.ts2str(time.div(stats.dur_avg, stats.cnt)) .. "\n")
	     else
		stats.cnt = stats.cnt+1
		local s = luagc.timed_gc(type)
		stats.dur_avg = time.add(stats.dur_avg, s.dur)

		if time.cmp(s.dur, stats.dur_min) < 0 then
		   stats.dur_min = s.dur
		end

		if time.cmp(s.dur, stats.dur_max) > 0 then
		   stats.dur_max = s.dur
		end
	     end
	  end
end

-- function () print(luagc.gcstat_tostring(luagc.timed_gc("collect"))) end
local progs = {
   entry=create_bench("step"),
--   doo = function (fsm, state, type)
-- 	    rtposix.nanosleep("REALTIME", "rel", 0, 1)
-- 	    -- print("sending e_trigger")
-- 	    -- rtfsm.send_events(fsm, "e_trigger")
-- 	 end
}

-- create fsm
local fsm = rtfsm.init(fsmbuilder.flat_chain_fsm(100, progs), "fsm_dyn_test")
assert(fsm, "fsm init failed")
fsm2uml.fsm2uml(fsm, "png", "fsm_dyn_test-uml.png")

-- perform full collect and stop gc
luagc.full()

for i=1,10000 do
   rtfsm.step(fsm)
   rtfsm.send_events(fsm, "e_trigger")
end

progs.entry("print_results")
