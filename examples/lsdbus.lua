#!/usr/bin/lua
--
-- Small example of using rFSM with lsdbus
-- $ lsdb-emit  /,test.rfsm,ping
-- $ lsdb-emit  /,test.rfsm,exit


local lsdb = require("lsdbus")
local rfsm = require("rfsm")
local timeevent = require("rfsm.timeevent")
local pp = require("rfsm.pp")
local have_luajit, ffi = pcall(require, "ffi")
local have_posix, posix = pcall(require, "posix")

local e_after = timeevent.e_after

local timeouts = {
   IDLE = 10,
}

local function gettimeout(id) return timeouts[id] end

timeevent.DEBUG=true

local bus
local NSEC_PER_SEC = 1000 * 1000 * 1000

if have_luajit then
   print("using ffi based gettime")
   ffi.cdef[[
typedef struct { long tv_sec; long tv_nsec; } timespec;
int clock_gettime(int clk_id, timespec* tp);
]]

   local ts = ffi.new("timespec")
   local function gettime_nsec()
      ffi.C.clock_gettime(1, ts)
      return ffi.new("int64_t", ts.tv_sec) * NSEC_PER_SEC + ffi.new("int64_t", ts.tv_nsec)
   end
   timeevent.set_gettime_hook(gettime_nsec)
elseif have_posix then
   print("using posix time")
   local function gettime_nsec()
      local sec,nsec = posix.clock_gettime(posix.CLOCK_MONOTONIC)
      return sec * NSEC_PER_SEC + nsec
   end
   timeevent.set_gettime_hook(gettime_nsec)
else
   print("falling back on os.time")
   timeevent.set_gettime_hook(function() return os.time * NSEC_PER_SEC end)
end


local fsm = rfsm.init(
   rfsm.csta {
      dbg = pp.gen_dbgcolor("lsdb-test", {STATE_ENTER=true, STATE_EXIT=true, RAISED=true}, true),

      -- normal operational state. while receiving e_ping events, stay
      -- in active, if none are received with 2sec go to idle.
      running = rfsm.csta {
	 active = rfsm.state{},
	 idle = rfsm.state{},

	 rfsm.trans{ src="initial", tgt="active" },
	 rfsm.trans{ src="idle",    tgt="active", events={"e_ping"} },
	 rfsm.trans{ src="active",  tgt="active", events={"e_ping"} },
	 rfsm.trans{ src="active",  tgt="idle",   events={e_after(gettimeout)} },
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
