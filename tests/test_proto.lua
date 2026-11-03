-- Tests for the rfsm.proto UDP introspection protocol.
--
-- SPDX-License-Identifier: BSD-3-Clause

local lu = require("luaunit")
local rfsm = require("rfsm")
local C = require("common")

TestProto = {}

-- rfsm.proto never closes its socket, so each test needs its own port
local port = 44944

-- rfsm.proto installs a global preproc hook: keep it local to the test.
-- @param conf rfsm.proto configuration
-- @return initialized fsm in state a, udp client socket
local function setup(conf)
   local proto = require("rfsm.proto")
   local socket = require("socket")
   local npreproc = #rfsm.preproc
   port = port + 1
   conf.host, conf.port = "127.0.0.1", port
   proto.install(conf)
   local ok, fsm = pcall(C.init, rfsm.csta{
      a = rfsm.sista{},
      b = rfsm.sista{},
      rfsm.trans{ src='initial', tgt='a' },
      rfsm.trans{ src='a', tgt='b', events={ 'e_go' } },
   })
   rfsm.preproc[npreproc + 1] = nil
   assert(ok, fsm)
   rfsm.run(fsm)
   lu.assert_equals(C.fqn(fsm), "root.a")
   local client = assert(socket.udp())
   assert(client:setpeername("127.0.0.1", port))
   return fsm, client
end

local function send_event(fsm, client)
   assert(client:send('{"type":"event","event":"e_go"}'))
   rfsm.step(fsm)
   rfsm.run(fsm)
end

function TestProto:setUp()
   for _, m in ipairs{ "socket", "json" } do
      if not pcall(require, m) then lu.skip(m .. " not available") end
   end
end

function TestProto:test_event_is_dropped_without_allow_send()
   local fsm, client = setup{}
   send_event(fsm, client)
   lu.assert_equals(C.fqn(fsm), "root.a")
end

function TestProto:test_event_is_raised_with_allow_send()
   local fsm, client = setup{ allow_send=true }
   send_event(fsm, client)
   lu.assert_equals(C.fqn(fsm), "root.b")
end

function TestProto:test_bad_packets_are_ignored()
   local fsm, client = setup{ allow_send=true }
   for _, data in ipairs{ '{', 'not json', '5', 'null', '"x"', '[]', '{}' } do
      assert(client:send(data))
      rfsm.step(fsm)
      rfsm.run(fsm)
      lu.assert_equals(C.fqn(fsm), "root.a")
   end
   send_event(fsm, client)
   lu.assert_equals(C.fqn(fsm), "root.b")
end

return TestProto
