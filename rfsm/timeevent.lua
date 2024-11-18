-- rFSM time events
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2024 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- This module extends the core rFSM model with time events.  A
-- time-event is specified using the `e_after(timespec)` or
-- `e_at(timespec)`. A timespec is floating point value in seconds.
-- (Note: currently only relative (e_after) timeevents are
-- implemented).
--
-- This implementation intentionally omits the os-dependent aspect of
-- getting the current time. Hence, after loading this module an
-- appropriate `gettime` function must be installed by using
-- `set_gettime_hook(f)`, where `f`is a function which returns two
-- values: the absolute time in seconds and nanoseconds (following the
-- POSIX `clock_nanosleep(2)`).
--
-- The implementation consists of a preprocessing step that expands
-- the specification to e_after(timespec) to the canonical form
-- e_after(timespec)@source fqn and installs an entry handler to
-- stores the entry time. A second handler (._check_timeevent) is is
-- stored in the source state that when called, checks for expiration
-- and (possibly) generates the time event. A "master" timeevent check
-- function (check_act_timeevents) calls all check_ handlers of the
-- current active states during post_step_hook.


local utils = require("utils")
local rfsm = require("rfsm")

local M = {}

M.DEBUG = false

local gettime = false

local NSEC_PER_SEC = 1000000000

local timeevent_mt = {}
timeevent_mt.__index = timeevent_mt

function timeevent_mt:__tostring()
   return 'e_after(' .. self.id .. ')'
end

function M.e_after(x, id)
   local o = { type='e_after' }

   if type(x) == 'number' then
      o.id = id or tostring(x)
      o.gettimeout = function() return x end
   elseif type(x) == 'function' then
      o.id = id or string.match(tostring(o), "table:%s(.*)")
      o.gettimeout = x
   else
      error("e_after: invalid arg 1: expected function, got ".. type(x))
   end

   return setmetatable(o, timeevent_mt)
end

function M.is_timeevent(x)
   return getmetatable(x) == timeevent_mt
end

--- Setup the gettime function to be used by this module.
-- @param f function which is expected to return two values sec and nsec.
function M.set_gettime_hook(f)
   assert(type(f) == 'function', "set_gettime_hook: parameter not a function")
   gettime = f
end

--- Generate two timeevent manager functions.
-- returns two functions: reset and check. The first will reset the
-- internally stored time. The second checks if the timeevent has
-- become true and if yes raises the event 'name'.
-- @param name name of event to raise
-- @param id id to pass to gettimeout callbacl
-- @param gettimeout gettimeout function (must return timeout in nsec)
-- @param sendf function to call for sending events
-- @param fsm fsm for dbg functions
local function gen_rel_timeevent_mgr(name, id, gettimeout, sendf, fsm)
   assert(type(gettime) == 'function', "rfsm.timeevent: no gettime function set.")

   local tentry = false
   local fired = false

   local function reset()
      tentry = gettime()
      fired = false
      if M.DEBUG then
	 fsm.dbg("TIMEEVENT", "reset timevent " .. name .. " tentry: " .. tostring(tentry))
      end
   end

   local function check()
      if fired then return end

      local tnow = gettime()
      local timeout = gettimeout(id) * NSEC_PER_SEC
      local tend = tentry + timeout

      if M.DEBUG then
	 fsm.dbg("TIMEEVENT", "checking timevent " .. name ..
		 " tentry: " .. tostring(tentry) ..
		 ", timeout: " .. tostring(timeout))
      end

      if tnow > tend then
	 sendf(name)
	 fired = true
      end
   end

   return reset, check
end

--- Pre-process timevents and setup handlers.
-- @param fsm initalized root fsm.
local function expand_timeevent(fsm)
   local function se(...) rfsm.send_events(fsm, ...) end

   fsm.info("rfsm.timeevent: time-event extension loaded")

   rfsm.mapfsm(function (tr, p)
	 if not tr.events then return end
	 for i=1,#tr.events do
	    local e = tr.events[i]

	    -- handle old-school timevents
	    if type(e) == 'string' then
	       local timespec = tonumber(string.match(e, "e_after%((.*)%)"))

	       if timespec then
		  fsm.dbg("converting timeevent " .. e .. " to new style")
		  e = M.e_after(timespec)
		  tr.events[i] = e
	       end
	    end

	    if M.is_timeevent(e) then
	       local eexp = tostring(e) .. '@' .. tr.src._fqn
	       tr.events[i] = eexp
	       local reset, check = gen_rel_timeevent_mgr(eexp, e.id, e.gettimeout, se, fsm)
	       tr.src.entry = utils.advise('before', tr.src.entry, reset)
	       tr.src._check_timeevent = check
	    end
	 end
   end, fsm, rfsm.is_trans)

   local function check_act_timeevents(fsm)
      local function check_timeevent(fsm, sta)
	 if sta._check_timeevent then sta._check_timeevent() end
      end
      rfsm.map_from_to(fsm, check_timeevent, fsm._act_leaf, fsm)
   end

   rfsm.post_step_hook_add(fsm, check_act_timeevents)
end

rfsm.preproc[#rfsm.preproc+1] = expand_timeevent

return M
