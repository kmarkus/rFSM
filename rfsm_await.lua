-- rFSM await extension.
-- Trigger on events received in different steps.
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2020 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- syntax: events={ "await('e_foo', 'e_bar')" } will trigger when both
-- e_foo and e_bar have been received.
--
-- Note that await is internally transformed to separate events in the
-- events table plus a guard condition.
--

local rfsm = require("rfsm")
local utils = require("utils")
local string, print, ipairs, pairs = string, print, ipairs, pairs
local get_sta_mode = rfsm.get_sta_mode

local M = {}

--- Pre-process await and setup handlers.
-- @param fsm initalized root fsm.
local function expand_await(fsm)

   fsm.info("rfsm_await: await extension loaded")

   --- check and parse an await spec.
   -- @returns a table of await events or false if event is not an
   -- an await
   local function parse_await(event)
      local awaitspec = string.match(event, "await%((.*)%)")
      if not awaitspec then return false end
      awaitspec = string.gsub(awaitspec, "['\"]", "") -- remove ["']
      local evlist = utils.split(awaitspec, ",") --
      return utils.map(utils.trim, evlist) -- trim whitespace
   end

   --- Generate await handlers.
   -- Generate update, reset and guard functions.
   local function gen_await_handlers(await_events, tr)
      local etab={}
      local aw_src_sta=tr.src -- caching this is OK in terms of
			      -- dynamic FSM changes, since if this
			      -- state is replaced, then its
			      -- transitions will need an update too.

      local function reset()
	 fsm.dbg("AWAIT", "reset await monitoring")
	 for _,e in ipairs(await_events) do etab[e]=false end
      end

      -- make sure that only await_events get set
      local function update(fsm, events)
	 if get_sta_mode(aw_src_sta) == 'inactive' then return end
	 for _,e in ipairs(events) do
	    if etab[e]~=nil and etab[e]==false then
	       etab[e]=true
	       fsm.dbg("AWAIT", "update received:", e)
	    end
	 end
      end

      local function _cond(events)
	 for e,v in pairs(etab) do
	    if not v then return false end
	 end
	 return true
      end

      local function cond(events)
	 local res = _cond(events)
	 fsm.dbg("AWAIT", "checking await condition:", res)
	 return res
      end

      reset()

      return update, reset, cond
   end

   rfsm.mapfsm(function (tr, p)
		  if not tr.events then return end
		  for i=1,#tr.events do
		     local await_events = parse_await(tr.events[i])
		     if await_events then
			fsm.dbg("AWAIT", "matched await spec " .. tr.events[i])
			local update, reset, cond = gen_await_handlers(await_events, tr)

			for _,e in ipairs(await_events) do tr.events[#tr.events+1] = e end

			rfsm.pre_step_hook_add(fsm, update) -- update prior to each step
			tr.src.exit = utils.advise('after', tr.src.exit, reset) -- reset on src state exit

			if tr.guard then
			   old_guard = tr.guard
			   tr.guard=function(...) return cond(...) and old_guard(...) end
			else
			   tr.guard = cond
			end
		     end
		  end
	       end, fsm, rfsm.is_trans)
end


rfsm.preproc[#rfsm.preproc+1] = expand_await

return M
