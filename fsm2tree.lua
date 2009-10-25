#!/usr/bin/lua

require('gv')
require('fsmutils')

local pairs, ipairs, print, table, type, assert, gv, io, fsmutils
   = pairs, ipairs, print, table, type, assert, gv, io, fsmutils

module("fsm2tree")

param = {}
param.show_fqn = false
param.layout="dot"
param.dbg=print
param.err=print


-- overall state properties

local function set_sprops(h)
   gv.setv(h, "style", "rounded")
   gv.setv(h, "shape", "box")
end

-- create new graph and add root node
local function new_graph(fsm)
   local gh = gv.digraph("hierarchical chart: " .. fsm.id)
   gv.setv(gh, "rankdir", "TD")

   local nh = gv.node(gh, fsm.fqn)
   set_sprops(nh)

   return gh
end

-- add any type of state
local function add_state(gh, parent, state)

   local nh = gv.node(gh, state.fqn)
   set_sprops(nh)

   local eh = gv.edge(gh, parent.fqn, state.fqn)
   gv.setv(eh, "arrowhead", "none")

   if not param.show_fqn then
      gv.setv(nh, "label", state.id)
   end
end

-- add a transition from src to tgt
local function add_trans(gh, src, tgt)
   local eh = gv.edge(gh, src.fqn, tgt.fqn)
   gv.setv(eh, "constraint", "false")
end

local function fsm2gh(fsm)
   local gh = new_graph(fsm)
   fsmutils.map_state(function (s) add_state(gh, s.parent, s) end, fsm)

--   fsmutils.map_trans(function (t)
--			 add_trans(gh, t.src, t.tgt.fqn)

   return gh
end


-- convert fsm to 
function fsm2img(fsm, format, outfile)

   if not fsm.__initalized then
      param.err("fsm2tree ERROR: fsm " .. fsm.id .. " uninitialized")
      return false
   end

   local gh = fsm2gh(fsm)
   gv.layout(gh, param.layout)
   param.dbg("fsm2tree: running " .. param.layout .. " layouter")
   gv.render(gh, format, outfile)
   param.dbg("fsm2tree: rendering to " .. format .. ", written result to " .. outfile)
end
