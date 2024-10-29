#!/usr/bin/lua
--
-- Small example of using rFSM with lsdbus
-- $ lsdb-emit  /,test.rfsm,ping
-- $ lsdb-emit  /,test.rfsm,exit


local lsdb = require("lsdbus")
local posix = require("posix")
local rfsm = require("rfsm")
local timeevent = require("rfsm.timeevent")
local pp = require("rfsm.pp")

local bus

-- configure gettime hook
timeevent.set_gettime_hook(
   function() return posix.clock_gettime() end
)

local fsm = rfsm.init(
   rfsm.csta {
      dbg = pp.gen_dbgcolor(
	 "lsdb-test", {STATE_ENTER=true, STATE_EXIT=true, RAISED=true}, false),

      -- normal operational state. while receiving e_ping events, stay
      -- in active, if none are received with 2sec go to idle.
      running = rfsm.csta {
	 active = rfsm.state{},
	 idle = rfsm.state{},

	 rfsm.trans{ src="initial", tgt="active" },
	 rfsm.trans{ src="idle",    tgt="active", events={"e_ping"} },
	 rfsm.trans{ src="active",  tgt="active", events={"e_ping"} },
	 rfsm.trans{ src="active",  tgt="idle",   events={"e_after(2)"} },
      },

      -- shutdown state
      exit = rfsm.state {
	 entry=function()
	    print("bye")
	    bus:exit_loop()
	 end
      },

      rfsm.trans{ src="initial", tgt="running" },
      rfsm.trans{ src="running", tgt="exit", events={'e_SIGINT', 'e_exit'} },
})

local function handle_event(_,_,_,_,m)
   local e = "e_".. m
   rfsm.send_events(fsm, e)
   rfsm.run(fsm)
end

local function handle_sigint()
   rfsm.send_events(fsm, 'e_SIGINT')
   rfsm.run(fsm)
end

local function run() rfsm.run(fsm) end

-- main
bus = lsdb.open()

bus:match_signal(nil, nil, 'test.rfsm', nil, handle_event)
bus:add_signal(lsdb.SIGINT, handle_sigint)
bus:add_periodic(1*1000^2, 0, run)

run()
bus:loop()
