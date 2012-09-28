
--- rFSM await extension.
-- Trigger on events received in different steps.
--
-- syntax: events={ "await('e_foo', 'e_bar')" } will trigger when both
-- e_foo and e_bar have been received.
--
-- Note that await is internally transformed to separate events in the
-- events table plus a guard condition.
--

local rfsm = require "rfsm"
local utils = require "utils"
local string, print, ipairs, pairs = string, print, ipairs, pairs

module("rfsm_await")

dbg=false

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
   local function gen_await_handlers(await_events)
      local etab={}

      local function reset()
	 for _,e in ipairs(await_events) do etab[e]=false end
      end

      -- make sure that only await_events get set
      local function update(fsm, events)
	 for _,e in ipairs(events) do
	    if etab[e]~=nil then etab[e]=true end
	 end
      end

      local function cond(events)
	 for e,v in pairs(etab) do
	    if not v then return false end
	 end
	 return true
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
			local update, reset, cond = gen_await_handlers(await_events)

			for _,e in ipairs(await_events) do tr.events[#tr.events+1] = e end

			rfsm.pre_step_hook_add(fsm, update) -- update prior to each step
			tr.src.exit = utils.advise('after', tr.src.exit, reset) -- reset on src state exit
			tr.guard = utils.advise('before', tr.guard, cond) -- add check before guard
		     end
		  end
	       end, fsm, rfsm.is_trans)
end


rfsm.preproc[#rfsm.preproc+1] = expand_await
