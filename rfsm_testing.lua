-- rFSM testing support
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2020 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- define sets of input events and expected trajectory and test
-- against actually executed trajectory
--

require("rfsm")
require("rfsm2uml")
require("utils")
local ac = require("ansicolors")

local tab2str = utils.tab2str
local is_leaf = rfsm.is_leaf

module("rfsm_testing", package.seeall)

verbose = false

-- output
local function stdout(...)
   if verbose then utils.stdout(unpack(arg)) end
end

local function stderr(...)
   utils.stderr(...)
end

function activate_leaf(fsm, node, mode)
   assert(is_leaf(node), "can only activate leaf states!")
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
   if is_leaf(c) then return c end
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
--  pics = true|false, generate rfsm2uml snapshots for each step.

function test_fsm(fsm, test, verb, dbg)
   verbose = verb or false

   assert(fsm._initialized, "ERROR: test_fsm requires an initialized fsm!")
   stdout("TESTING:", test.id)

   if dbg then
      fsm.dbg = rfsmpp.gen_dbgcolor(test.id, {}, true)
   end

   if test.pics then
      rfsm2uml.rfsm2uml(fsm, "png", test.id .. "-0.png",  test.id .. " initial state")
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
      rfsm2uml.rfsm2uml(fsm, "png", imgfile, boiler)
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
