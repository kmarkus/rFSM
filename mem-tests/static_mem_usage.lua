-- test the static memory usage behavior of a fsm

require("rtfsm")
require("time")
require("luagc")
require("fsm2uml")
require("utils")
require("fsmbuilder")

-- random seed
math.randomseed(os.time())

-- will generate a fsm with num_states = size and num_trans=size*2 and
-- measure the memory consumption before and after gc
function test_fsm_size(n)
   luagc.start()
   utils.stderr(string.rep('-', 80))
   utils.stderr("test_fsm_size: num_states=" .. n .. ", num_trans=" .. n*2)
   --print("before init: ", luagc.gcstat_tostring(luagc.timed_gc("collect")))
   local fsm = rtfsm.init(fsmbuilder.rand_fsm(n, n*2), "fsm_" .. n .. n*2)
   luagc.full()
   utils.stdout(n .. ',', luagc.mem_usage())
   
   -- print("after init: ", luagc.gcstat_tostring(luagc.timed_gc("collect")))
   fsm2uml.fsm2uml(fsm, "png", "fsm_" .. n ..'_' .. n*2 .. "-uml.png")
end

for i=5,200,5 do
   test_fsm_size(i)
end


