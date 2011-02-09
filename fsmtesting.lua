--
-- This file is part of rFSM.
-- 
-- (C) 2010 Markus Klotzbuecher, markus.klotzbuecher@mech.kuleuven.be,
-- Department of Mechanical Engineering, Katholieke Universiteit
-- Leuven, Belgium.
-- 
-- You may redistribute this software and/or modify it under either
-- the terms of the GNU Lesser General Public License version 2.1
-- (LGPLv2.1 <http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>)
-- or (at your discretion) of the Modified BSD License: Redistribution
-- and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
--    1. Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--    2. Redistributions in binary form must reproduce the above
--       copyright notice, this list of conditions and the following
--       disclaimer in the documentation and/or other materials provided
--       with the distribution.  
--    3. The name of the author may not be used to endorse or promote
--       products derived from this software without specific prior
--       written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
-- OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
-- GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
-- WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- 

--
-- testing/debugging
--

-- define sets of input events and expected trajectory and test
-- against actually executed trajectory
--

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
