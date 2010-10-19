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
require("ansicolors")

local table = table
local io = io
local utils = utils
local rfsm = rfsm
local string = string
local fsm2uml = fsm2uml
local ac = ansicolors

local pairs = pairs
local ipairs = ipairs
local print = print
local type = type
local assert = assert
local tostring = tostring
local unpack = unpack

local tab2str = utils.tab2str
local sista = rfsm.sista
local is_sista = rfsm.is_sista
local csta = sista

module("fsmtesting")

local verbose = false

-- output
local function stdout(...)
   if verbose then utils.stdout(unpack(arg)) end
end

local function stderr(...)
   utils.stderr(unpack(arg))
end

--
-- activate all states including leaf but without running any programs
--
-- function activate_node(fsm, node)
--    assert(rfsm.is_sista(node), "can only set simple_states types active!")
--    rfsm.map_from_to(fsm, function (fsm, s)
-- 			    set_sta_mode(s, 'active')
-- 			 end, node, fsm)
-- end

function activate_sista(fsm, node, mode)
   assert(is_sista(node), "can only set simple_states types active!")
   rfsm.map_from_to(fsm, function (fsm, s) set_sta_mode(s, 'active') end, node, fsm)
   set_sta_mode(node, mode)
end


function reset(fsm)
   assert(nil, "tbd: implement reset func!")
end

--
-- return a table describing the active configuration
--
-- function __get_act_conf(fsm)

--    local function __walk_act_path(s)
--       local res = {}
--       -- 'done' or 'inactive' are always the end of the active conf
--       if s._mode ~= 'active' then
-- 	 return { [s._fqn]=s._mode }
--       end

--       if rfsm.is_csta(s) then
-- 	 for ac,_ in pairs(s._actchild) do
-- 	    res[s._id] = __walk_act_path(ac)
-- 	 end
--       elseif rfsm.is_sista(s) then
-- 	 return { [s._fqn]=s._mode }
--       else
-- 	 local mes="ERROR: active non state type found, fqn=" .. s.fqn .. ", type=" .. s:type()
-- 	 param.err(mes)
-- 	 return mes
--       end

--       return res
--    end

--    return __walk_act_path(fsm)
-- end

function get_act_leaf(fsm)
   local c = rfsm.actchild_get(fsm)
   if c == nil then
      error("get_act_leaf: no active child!")
      return false
   end
   if is_sista(c) then return c end
   return get_act_leaf(c)
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
      local boiler = "test: " .. t.descr .. '\n' ..
	 "   preact:      " .. tab2str(t.preact) .. '\n' ..
	 "   sent events: " .. tab2str(t.events) .. '\n' ..
	 "   pre intq:    " .. tab2str(fsm._intq) .. '\n'

      stdout(boiler)

      if t.preact then activate_sista(fsm, t.fqn, t.mode) end
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
