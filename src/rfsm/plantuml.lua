-- rFSM PlantUML state-diagram exporter.
--
-- (C) 2024 Markus Klotzbuecher <mk@mkio.de>
-- SPDX-License-Identifier: BSD-3-Clause
--
-- Render an initialized rFSM as a PlantUML state diagram. This is a
-- pure-Lua alternative to the (removed) graphviz based rfsm2uml and
-- has no external dependencies.
--
--   local plantuml = require("rfsm.plantuml")
--   print(plantuml.encode(fsm))        -- return the diagram as a string
--   plantuml.save(fsm, "model.puml")   -- ... or write it to a file
--
-- The output can be rendered with the `plantuml` tool or any of the
-- many online PlantUML servers.

local rfsm = require("rfsm")

local is_meta = rfsm.is_meta
local is_node = rfsm.is_node
local is_state = rfsm.is_state
local is_composite = rfsm.is_composite
local is_conn = rfsm.is_conn
local is_trans = rfsm.is_trans
local is_root = rfsm.is_root

local M = {}

-- turn a fqn into a valid PlantUML identifier
local function id(node) return (node._fqn:gsub("[^%w]", "_")) end

local function is_initial(node) return is_conn(node) and node._id == 'initial' end

-- format the events of a transition into a readable label (dropping the
-- internal '@fqn' suffix that e_done / timeevents carry)
local function label(tr)
   if not tr.events or #tr.events == 0 then return nil end
   local parts = {}
   for _, e in ipairs(tr.events) do
      parts[#parts+1] = (tostring(e):gsub("@.*$", ""))
   end
   return table.concat(parts, ", ")
end

-- the PlantUML target of an arrow: an initial connector means "enter the
-- enclosing composite", so we point at its parent. The root has no
-- enclosing block, so a transition back to the root initial uses [*].
local function tgt_ref(node)
   if is_initial(node) then
      if is_root(node._parent) then return "[*]" end
      return id(node._parent)
   end
   return id(node)
end

local function src_ref(node)
   if is_initial(node) then return "[*]" end
   return id(node)
end

-- recursively render the contents (sub-states and transitions) of a
-- composite state into the lines table
local function render(state, lines, ind)
   local pad = string.rep("  ", ind)

   -- declare child nodes
   for name, child in pairs(state) do
      if not is_meta(name) and is_node(child) then
	 if is_composite(child) then
	    lines[#lines+1] = pad .. 'state "' .. child._id .. '" as ' .. id(child) .. ' {'
	    render(child, lines, ind + 1)
	    lines[#lines+1] = pad .. '}'
	 elseif is_conn(child) then
	    if not is_initial(child) then
	       lines[#lines+1] = pad .. 'state "' .. child._id .. '" as ' .. id(child) .. ' <<choice>>'
	    end
	 else -- leaf state
	    lines[#lines+1] = pad .. 'state "' .. child._id .. '" as ' .. id(child)
	 end
      end
   end

   -- emit transitions defined at this level
   for _, tr in ipairs(state) do
      if is_trans(tr) then
	 local arrow = pad .. src_ref(tr.src) .. ' --> ' .. tgt_ref(tr.tgt)
	 local l = label(tr)
	 lines[#lines+1] = l and (arrow .. ' : ' .. l) or arrow
      end
   end
end

--- Encode an initialized fsm as a PlantUML state diagram.
-- @param fsm initialized rFSM instance
-- @param title optional diagram title
-- @return the diagram as a string
function M.encode(fsm, title)
   assert(rfsm.is_initialized_root(fsm), "rfsm.plantuml: initialized fsm required")
   local lines = { "@startuml" }
   if title then lines[#lines+1] = "title " .. title end
   render(fsm, lines, 0)
   lines[#lines+1] = "@enduml"
   return table.concat(lines, "\n") .. "\n"
end

--- Encode an fsm and write it to a file.
-- @param fsm initialized rFSM instance
-- @param file output file name
-- @param title optional diagram title
function M.save(fsm, file, title)
   local f = assert(io.open(file, "w"))
   f:write(M.encode(fsm, title))
   f:close()
end

return M
