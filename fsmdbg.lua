--
-- testing/debugging
--

-- define sets of input events and expected trajectory and test
-- against actually executed trajectory
--

--
-- activate all states including leaf but without running any programs
--


require ('luarocks.loader')
require('std')

require("rtfsm")
require("fsm2uml")
require("utils")

local pairs, ipairs, print, table, type, assert, io, utils, rtfsm, tostring, string, fsm2uml
   = pairs, ipairs, print, table, type, assert, io, utils, rtfsm, tostring, string, fsm2uml

module("fsmdbg")

--
-- activate a node and all parent
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

      if rtfsm.is_psta(s) then
	 res[s._id] = map(__walk_act_path, s._act_child)
      elseif rtfsm.is_csta(s) then
	 res[s._id] = __walk_act_path(s._act_child)
      elseif rtfsm.is_sista(s) then
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

function test_fsm(fsm, test)
   local function cmp_ac(act, exp)
      if not table_cmp(act, exp) then
	 print("FAILED: Active configurations differ!")
	 print("    actual:   " .. tostring(act))
	 print("    expected: " .. tostring(exp))
	 return false
      else
	 print("OK.")
	 return true
      end
   end

   local retval = true
   assert(fsm._initalized, "tests_fsm requires an initialized fsm!")
   print("TESTING:", test.id)

   fsm2uml.fsm2uml(fsm, "png", test.id .. "-0.png",  test.id .. " initial state")

   for i,t in ipairs(test.tests) do
      local ret
      local boiler = "test: " .. t.descr .. '\n' ..
	 "   preact:      " .. tostring(t.preact) .. '\n' ..
	 "   sent events: " .. tostring(t.events) .. '\n' ..
	 "   pre ievq:    " .. tostring(fsm._intq) .. '\n'

      print(boiler)

      utils.foreach(function (n) activate_node(fsm, n) end, t.preact)
      utils.foreach(function (e) rtfsm.send_events(fsm, e) end, t.events)

      rtfsm.step(fsm)

      ret = cmp_ac(get_act_conf(fsm), t.expect)
      print(string.rep("-", 80))
      fsm2uml.fsm2uml(fsm, "png", test.id .. "-" .. i .. ".png", boiler)
      retval = retval and ret
   end
   return retval
end
