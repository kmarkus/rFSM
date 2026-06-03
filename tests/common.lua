-- Shared helpers for the rFSM luaunit test-suite.
--
-- (C) 2024 Markus Klotzbuecher <mk@mkio.de>
-- SPDX-License-Identifier: BSD-3-Clause

local rfsm = require("rfsm")

local M = {}

-- directory of this file, so example paths work regardless of cwd
local sep = package.config:sub(1,1)
local here = (debug.getinfo(1, "S").source:sub(2):match("^(.*)" .. sep) or ".") .. sep
M.examples_dir = here .. ".." .. sep .. "examples" .. sep

--- Return the absolute path to an example model file (without extension).
function M.example(name)
   return M.examples_dir .. name .. ".lua"
end

--- Build and initialize an fsm from a template, asserting success.
-- Debug output is silenced by default.
-- @param templ rfsm state template
-- @return initialized fsm
function M.init(templ)
   if templ.dbg == nil then templ.dbg = false end
   if templ.info == nil then templ.info = false end
   if templ.warn == nil then templ.warn = false end
   local fsm = rfsm.init(templ)
   assert(fsm, "rfsm.init failed")
   return fsm
end

--- Load, initialize and return the fsm in the given example file.
-- @param file path to the rfsm model file
-- @return initialized fsm
function M.init_file(file)
   local fsm = rfsm.init(rfsm.load(file))
   assert(fsm, "rfsm.init of " .. file .. " failed")
   return fsm
end

--- Return the fully qualified name of the active leaf state (or "<none>").
function M.fqn(fsm)
   return rfsm.get_actleaf_fqn(fsm) or "<none>"
end

--- Return the mode ('active'|'done'|'inactive') of the active leaf state.
function M.mode(fsm)
   local al = fsm._act_leaf
   return al and rfsm.get_sta_mode(al) or "inactive"
end

--- Send the given events, then run the fsm to idle.
function M.send_run(fsm, ...)
   rfsm.send_events(fsm, ...)
   rfsm.run(fsm)
end

return M
