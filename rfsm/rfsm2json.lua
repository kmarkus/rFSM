-- rfsm fsm json encoding
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2020 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause

local rfsm = require("rfsm")
local rfsm_marsh = require("rfsm_marsh")
local json = require("json")
local utils = require("utils")
local pcall = pcall
local tostring = tostring
local print = print -- debugging only

local M = {}

-- shortcuts
local mapfsm = rfsm.mapfsm
local is_composite = rfsm.is_composite
local is_leaf = rfsm.is_leaf
local is_conn = rfsm.is_conn
local is_node = rfsm.is_node
local is_trans = rfsm.is_trans

local RFSM2JSON_VERSION = 2

--- msg format
-- { version=...
--   graph=....
--   active_leaf = <active state fqn>
--   active_leaf_state=<active,done,inactive>"
-- }
--- Convert an initialized rFSM instance to the json representation
-- @param fsm initalized rFSM instance
function M.encode(fsm)
   if not fsm._initialized then
      error("rfsm2json: initialized FSM required")
      return false
   end

   local res = { version=RFSM2JSON_VERSION, type='rfsm_model' }
   res.graph = rfsm_marsh.model2tab(fsm)
   if fsm._act_leaf then
      res.active_leaf=fsm._act_leaf._fqn
      res.active_leaf_state=get_sta_mode(fsm._act_leaf)
   else
      res.active_leaf = false
      res.active_leaf_state = false
   end
   return json.encode(res)
end

return M
