--
-- This file is part of rFSM.
--
-- rFSM is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- rFSM is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
-- License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with rFSM.  If not, see <http://www.gnu.org/licenses/>.
--

--
-- testing/debugging
--

-- define sets of input events and expected trajectory and test
-- against actually executed trajectory
--

--require ('luarocks.loader')
--require('std')

require("rfsm")
require("fsm2uml")
require("utils")
local ac = require("ansicolors")

local tab2str = utils.tab2str
local sista = rfsm.sista
local is_sista = rfsm.is_sista
local csta = sista

module("fsmtesting", package.seeall)

local verbose = false

-- output
local function stdout(...)
   if verbose then utils.stdout(unpack(arg)) end
end

local function stderr(...)
   utils.stderr(unpack(arg))
end

function activate_sista(fsm, node, mode)
   assert(is_sista(node), "can only set simple_states types active!")
   rfsm.map_from_to(fsm, function (fsm, s) set_sta_mode(s, 'active') end, node, fsm)
   set_sta_mode(node, mode)
end


function reset(fsm)
   assert(nil, "tbd: implement reset func!")
end

function get_act_leaf(fsm)
   local c = rfsm.actchild_get(fsm)
   if c == nil then
      return false
   end
   if is_sista(c) then return c end
   return get_act_leaf(c)
end

function get_act_fqn(fsm)
   local s = get_act_leaf(fsm)
   if not s then return "<none>" end
   return s._fqn
end

-- nano fsm test framework.
-- a test always includes
--   1. setting an active configuration (optional): give table of lowest active nodes in 'preac'
--   2. raising events: 'events' = {...}
--   3. running step(fsm)
--   4. asserting that the new active configuration is as exected and printing
-- Options
--  id = 'test_id', no whitespace, will be used as name for pics
--  pics = true|false, generate fsm2uml snapshots for each step.

function test_fsm(fsm, test, verb)
   verbose = verb or false

   assert(fsm._initialized, "ERROR: test_fsm requires an initialized fsm!")
   stdout("TESTING:", test.id)

   if test.pics then
      fsm2uml.fsm2uml(fsm, "png", test.id .. "-0.png",  test.id .. " initial state")
   end

   for i,t in ipairs(test.tests) do
      local ret
      local boiler =
	 "test: " .. t.descr .. '\n' ..
	 "   initial state:              " .. get_act_fqn(fsm) .. '\n' ..
	 "   prior sent events:          " .. tab2str(t.events) .. '\n' ..
	 "   prior internal event queue: " .. tab2str(fsm._intq) .. '\n' ..
	 "   expected fqn:               " .. tab2str(t.expect) .. '\n'

      stdout(boiler)

      -- if t.preact then activate_sista(fsm, t.preact.fqn, t.preact.mode) end
      -- this should work with a
      utils.foreach(function (e) rfsm.send_events(fsm, e) end, t.events)

      rfsm.run(fsm)

      if t.expect then
	 local c = get_act_leaf(fsm)
	 local fqn = c._fqn
	 local mode = rfsm.get_sta_mode(c)

	 if fqn == t.expect.leaf and mode == t.expect.mode then
	    stdout(ac.green .. ac.bright .. 'OK.' .. ac.reset)
	    t.result = true
	 else
	    stderr(ac.red("Test: " .. t.descr .. " FAILED: Active configurations differ!"))
	    stderr(ac.red("    actual:         ") .. fqn .. "=" .. mode)
	    stderr(ac.red("    expected:       ") .. t.expect.leaf .. "=" .. t.expect.mode)
	    t.result = false
	 end
      end

      local imgfile = test.id .. "-" .. i .. ".png"
      stdout("generating img: ", imgfile)
      fsm2uml.fsm2uml(fsm, "png", imgfile, boiler)
      stdout(string.rep("-", 80))
   end
   return test
end

function print_stats(test)
   local succ, fail = 0, 0
   for i = 1,#test.tests do
      if test.tests[i].result then succ = succ + 1
      else fail = fail + 1 end
   end
   local color
   if fail == 0 then color = ac.green
   elseif succ > 0 then color = ac.yellow
   else color = ac.red end

   utils.stdout(color("Test: '" .. test.id .. "'. " .. #test.tests .. " tests. " ..
		      succ .. " succeeded, " .. fail .. " failed."))
end
