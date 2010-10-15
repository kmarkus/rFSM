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

local pairs, ipairs, print, table, type, assert, io, utils, rfsm,
   tostring, string, fsm2uml, ansicolors, unpack = pairs, ipairs,
   print, table, type, assert, io, utils, rfsm, tostring, string,
   fsm2uml, ansicolors, unpack

local tab2str = utils.tab2str

module("fsmtesting")

local verbose = false

-- output
local function stdout(...)
   if verbose then
      utils.stdout(unpack(arg))
   end
end

local stderr = utils.stderr

--
-- activate all states including leaf but without running any programs
--
function activate_node(fsm, node)
   assert(is_sta(node), "can only set states types active!")
   map_from_to(fsm, function (fsm, s)
		       sta_mode(s, 'active')
		    end, node, fsm)
end


function reset(fsm)
   assert(nil, "tbd: implement reset func!")
end

--
-- return a table describing the active configuration
--
function get_act_conf(fsm)

   local function __walk_act_path(s)
      local res = {}
      -- 'done' or 'inactive' are always the end of the active conf
      if s._mode ~= 'active' then
	 return { [s._fqn]=s._mode }
      end

      if rfsm.is_csta(s) then
	 for ac,_ in pairs(s._actchild) do
	    res[s._id] = __walk_act_path(ac)
	 end
      elseif rfsm.is_sista(s) then
	 return { [s._fqn]=s._mode }
      else
	 local mes="ERROR: active non state type found, fqn=" .. s.fqn .. ", type=" .. s:type()
	 param.err(mes)
	 return mes
      end

      return res
   end

   return __walk_act_path(fsm)
end

-- compare two tables
function table_cmp(t1, t2)
   local function __cmp(t1, t2)
      -- t1 _and_ t2 are not tables
      if not (type(t1) == 'table' and type(t2) == 'table') then
	 if t1 == t2 then return true
	 else return false end
      elseif type(t1) == 'table' and type(t2) == 'table' then
	 if #t1 ~= #t2 then return false
	 else
	    -- iterate over all keys and compare against k's keys
	    for k,v in pairs(t1) do
	       if not __cmp(t1[k], t2[k]) then
		  return false
	       end
	    end
	    return true
	 end
      else -- t1 and t2 are not of the same type
	 return false
      end
   end
   return __cmp(t1,t2) and __cmp(t2,t1)
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

   local function cmp_ac(act, exp)
      if not table_cmp(act, exp) then
	 stderr(ansicolors.red("FAILED: Active configurations differ!"))
	 stderr(ansicolors.red("    actual:   ") .. utils.tab2str(act))
	 stderr(ansicolors.red("    expected: ") .. utils.tab2str(exp))
	 return false
      else
	 stdout(ansicolors.green .. ansicolors.bright .. 'OK.' .. ansicolors.reset)
	 return true
      end
   end

   local retval = true
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

      utils.foreach(function (n) activate_node(fsm, n) end, t.preact)
      utils.foreach(function (e) rfsm.send_events(fsm, e) end, t.events)

      rfsm.run(fsm)

      if t.expect then
	 ret = cmp_ac(get_act_conf(fsm), t.expect)
      elseif t.expect_str then
	 ret = check_status(get_act_conf(fsm), t.expect_str)
      end

      local imgfile = test.id .. "-" .. i .. ".png"
      stdout("generating img: ", imgfile)
      fsm2uml.fsm2uml(fsm, "png", imgfile, boiler)
      retval = retval and ret
      stdout(string.rep("-", 80))
   end
   return retval
end
