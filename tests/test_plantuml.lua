-- Tests for the PlantUML exporter (rfsm.plantuml).
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

TestPlantuml = {}

local function sample()
   return C.init(rfsm.csta{
      operational = rfsm.sista{},
      faults = rfsm.csta{
         hardware_err = rfsm.sista{},
         dispatch = rfsm.conn{},
         rfsm.trans{ src='initial', tgt='dispatch' },
         rfsm.trans{ src='dispatch', tgt='hardware_err', events={ 'e_hw' } },
      },
      rfsm.trans{ src='initial', tgt='operational' },
      rfsm.trans{ src='operational', tgt='faults.dispatch', events={ 'e_error' } },
   })
end

function TestPlantuml:test_encode_basics()
   local pu = require("rfsm.plantuml")
   local s = pu.encode(sample())
   lu.assert_is_string(s)
   lu.assert_str_matches(s, "^@startuml.*")
   lu.assert_str_matches(s, ".*@enduml%s*$")
end

function TestPlantuml:test_states_and_nesting()
   local pu = require("rfsm.plantuml")
   local s = pu.encode(sample())
   lu.assert_str_contains(s, 'state "operational" as root_operational')
   lu.assert_str_contains(s, 'state "faults" as root_faults {')   -- composite block
   lu.assert_str_contains(s, '<<choice>>')                         -- connector
end

function TestPlantuml:test_transitions_and_initial()
   local pu = require("rfsm.plantuml")
   local s = pu.encode(sample())
   lu.assert_str_contains(s, '[*] --> root_operational')          -- root initial
   lu.assert_str_contains(s, ' : e_error')                         -- event label
   -- a transition targeting a composite's initial enters the composite
   lu.assert_str_contains(s, 'root_operational --> root_faults_dispatch')
end

function TestPlantuml:test_title()
   local pu = require("rfsm.plantuml")
   local s = pu.encode(sample(), "My Title")
   lu.assert_str_contains(s, "title My Title")
end

function TestPlantuml:test_requires_initialized()
   local pu = require("rfsm.plantuml")
   lu.assert_error(function() pu.encode(rfsm.csta{}) end)
end

return TestPlantuml
