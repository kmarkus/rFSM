-- convert an rfsm model to a graphviz tree
--
-- (C) 2010-2013 Markus Klotzbuecher <markus.klotzbuecher@mech.kuleuven.be>
-- (C) 2014-2020 Markus Klotzbuecher <mk@mkio.de>
--
-- SPDX-License-Identifier: BSD-3-Clause

local gv = require("gv")
local rfsm = require("rfsm")
local utils = require("utils")

local pairs, ipairs, print, table, string, type, assert, gv, io, rfsm
   = pairs, ipairs, print, table, string, type, assert, gv, io, rfsm

local M = {}

local param = {}

param.trfontsize = 7.0
param.show_fqn = false
param.and_color="green"
param.and_style="dashed"
param.hedge_color="blue"
param.hedge_style="dotted"

param.layout="dot"
param.err=print
param.dbg = function () return true end

-- overall state properties

local function set_sprops(nh)
   gv.setv(nh, "style", "rounded")
   gv.setv(nh, "shape", "box")
end

local function set_ini_sprops(nh)
   gv.setv(nh, "shape", "point")
   gv.setv(nh, "height", "0.15")
end

local function set_fini_sprops(nh)
   gv.setv(nh, "shape", "doublecircle")
   gv.setv(nh, "label", "")
   gv.setv(nh, "height", "0.1")
end

local function set_hier_trans_props(eh)
   gv.setv(eh, "arrowhead", "none")
   gv.setv(eh, "style", param.hedge_style)
   gv.setv(eh, "color", param.hedge_color)
end

local function set_trans_props(eh)
   gv.setv(eh, "fontsize", param.trfontsize)
end

-- create new graph and add root node
local function new_graph(fsm)
   local gh = gv.digraph("hierarchical chart: " .. fsm._id)
   gv.setv(gh, "rankdir", "TD")

   local nh = gv.node(gh, fsm._fqn)
   set_sprops(nh)

   return gh
end

-- add regular type of state
local function add_state(gh, parent, state)

   local nh = gv.node(gh, state._fqn)
   set_sprops(nh)

   local eh = gv.edge(gh, parent._fqn, state._fqn)
   set_hier_trans_props(eh)

   if not param.show_fqn then
      gv.setv(nh, "label", state._id)
   end
end

-- add initial states
local function add_ini_state(gh, tr, parent)
   local nh, eh
   if tr.src._id == 'initial' then
      nh = gv.node(gh, parent._fqn .. '.initial')
      set_ini_sprops(nh)
      eh = gv.edge(gh, parent._fqn, parent._fqn .. '.initial')
      set_hier_trans_props(eh)
   end
end

-- add  final states
local function add_fini_state(gh, tr, parent)
   local nh, eh
   if tr.tgt._id == 'final' then
      nh = gv.node(gh, parent._fqn .. '.final')
      set_fini_sprops(nh)
      eh = gv.edge(gh, parent._fqn, parent._fqn .. '.final')
      set_hier_trans_props(eh)
   end
end


-- add a transition from src to tgt
local function add_trans(gh, tr, parent)
   local src, tgt, eh

   if tr.src == 'initial' then src = parent._fqn .. '.initial'
   else src = tr.src._fqn end

   if tr.tgt == 'final' then tgt = parent._fqn .. '.final'
   else tgt = tr.tgt._fqn end

   eh = gv.edge(gh, src, tgt)
   gv.setv(eh, "constraint", "false")
   if tr.events then gv.setv(eh, "label", table.concat(tr.events, ', ')) end
   set_trans_props(eh)
end

local function fsm2gh(fsm)
   local gh = new_graph(fsm)
   rfsm.mapfsm(function (tr, p) add_ini_state(gh, tr, p) end, fsm, rfsm.is_trans)
   rfsm.mapfsm(function (s) add_state(gh, s._parent, s) end, fsm, rfsm.is_state)
   rfsm.mapfsm(function (tr, p) add_fini_state(gh, tr, p) end, fsm, rfsm.is_trans)

   rfsm.mapfsm(function (tr, p) add_trans(gh, tr, p) end, fsm, rfsm.is_trans)
   return gh
end


-- convert fsm to
function M.rfsm2tree(fsm, format, outfile)

   if not fsm._initialized then
      param.err("rfsm2tree ERROR: fsm " .. (fsm._id or 'root') .. " uninitialized")
      return false
   end

   local gh = fsm2gh(fsm)
   gv.layout(gh, param.layout)
   param.dbg("rfsm2tree: running " .. param.layout .. " layouter")
   gv.render(gh, format, outfile)
   param.dbg("rfsm2tree: rendering to " .. format .. ", written result to " .. outfile)
end

return M
