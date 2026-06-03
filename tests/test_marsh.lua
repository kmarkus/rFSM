-- Tests for the marshalling helpers (rfsm.marsh) and json encoding
-- (rfsm.rfsm2json).
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

TestMarsh = {}

local function sample()
   return C.init(rfsm.csta{
      idle = rfsm.sista{},
      work = rfsm.csta{
         a = rfsm.sista{},
         conn = rfsm.conn{},
         rfsm.trans{ src='initial', tgt='a' },
         rfsm.trans{ src='a', tgt='conn', events={ 'e_done' } },
      },
      rfsm.trans{ src='initial', tgt='idle' },
      rfsm.trans{ src='idle', tgt='work', events={ 'e_start' } },
   })
end

function TestMarsh:test_model2tab_structure()
   local marsh = require("rfsm.marsh")
   local tab = marsh.model2tab(sample())
   lu.assert_equals(tab.id, "root")
   lu.assert_equals(tab.type, "state")
   lu.assert_is_table(tab.subnodes)
   lu.assert_is_table(tab.transitions)
   -- find the 'work' composite among the subnodes
   local names = {}
   for _, n in ipairs(tab.subnodes) do names[n.id] = n end
   lu.assert_not_nil(names.idle)
   lu.assert_not_nil(names.work)
   lu.assert_is_table(names.work.subnodes)
end

function TestMarsh:test_model2tab_requires_initialized()
   local marsh = require("rfsm.marsh")
   lu.assert_error(function() marsh.model2tab(rfsm.csta{}) end)
end

function TestMarsh:test_actinfo2tab()
   local marsh = require("rfsm.marsh")
   local fsm = sample()
   rfsm.run(fsm)
   local fqn, mode = marsh.actinfo2tab(fsm)
   lu.assert_equals(fqn, "root.idle")
   lu.assert_equals(mode, "done")
end

function TestMarsh:test_rfsm2json_encode()
   local r2j = require("rfsm.rfsm2json")
   local fsm = sample()
   rfsm.run(fsm)
   local s = r2j.encode(fsm)
   lu.assert_is_string(s)
   lu.assert_str_matches(s, '.*active_leaf.*')
   lu.assert_str_matches(s, '.*root%.idle.*')
end

return TestMarsh
