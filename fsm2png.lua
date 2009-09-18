#!/usr/bin/lua

require('gv')
require("gv")

param = {}
param.fontsize = 12.0
param.trfontsize = 7.0
param.ndfontsize = 8.0
param.layout="dot"
param.format="png"
param.cs_border_color = "black"
param.cs_fillcolor = "grey"

dbg = print

-- setup common properties
local function set_props(sh)
   gv.setv(sh, "fixedsize", "false")
   gv.setv(sh, "fontsize", param.fontsize)
end

local function set_trprops(sh)
   gv.setv(sh, "fixedsize", "false")
   gv.setv(sh, "fontsize", param.trfontsize)
end

local function set_ndprops(sh)
   gv.setv(sh, "fixedsize", "false")
   gv.setv(sh, "fontsize", param.ndfontsize)
end


-- return handles for different types of states
local function get_shandle(gh, name)

   if name == gv.nameof(gh) then 
      return gh, "graph"
   end

   local sh = gv.findsubg(gh, "cluster_" .. name)
   if sh then return sh, "subgraph" end

   local nh = gv.findnode(gh, name)
   if nh then return nh, "node" end

   io.stderr:write("No state '" .. name .. "'\n")
   return false
end

-- create a new graph
function new_gra(name)
   local gh = gv.digraph(name)
   set_props(gh)
   gv.setv(gh, "compound", "true")
   gv.setv(gh, "fontsize", param.fontsize)
   gv.setv(gh, "labelloc", "t")
   gv.setv(gh, "label", name)
   gv.setv(gh, "remincross", "true")
   gv.setv(gh, "splines", "true")
   gv.setv(gh, "rankdir", "TD")

   dbg("creating new graph " .. name)
   return gh
end

-- create initial state
function new_inista(gh, pstr)

   local ph = get_shandle(gh, pstr)
   assert(ph)
   name = pstr .. "_initial"

   if gv.findnode(ph, name) then
      io.stderr:write("graph " .. pstr .. "already has a initial node\n")
      return false
   end

   local nh = gv.node(ph, name)
   set_ndprops(n)
   gv.setv(nh, "shape", "point")
   gv.setv(nh, "height", "0.15")

   dbg("creating new initial state in '" .. pstr .. "'")

   return nh
end

-- create final state
function new_finsta(gh, pstr)

   local ph = get_shandle(gh, pstr)
   assert(ph)
   name = pstr .. "_final"

   if gv.findnode(ph, name) then
      io.stderr:write("graph " .. pstr .. "already has a final node\n")
      return false
   end

   local nh = gv.node(ph, name)
   set_ndprops(nh)
   gv.setv(nh, "shape", "doublecircle")
   gv.setv(nh, "label", "")
   gv.setv(nh, "height", "0.1")

   dbg("creating new final state in '" .. pstr .. "'")

   return nh
end

-- create a new simple state
function new_sista(gh, pstr, name, label)

   local ph = get_shandle(gh, pstr)
   assert(ph)

   -- tbd: use gh here?
   if gv.findnode(ph, name) then
      io.stderr:write("graph already has a node " .. name .. "\n")
      return false
   end

   local nh = gv.node(ph, name)
   set_ndprops(nh)

   gv.setv(nh, "style", "rounded")
   gv.setv(nh, "shape", "box")
   if label then gv.setv(nh, "label", name .. "\n" .. label) end

   dbg("creating new simple state '" .. name .. "' in '" .. pstr .. "'")

   return nh
end

-- create an new composite state
function new_csta(gh, parent, name, label)

   local ph = get_shandle(gh, parent)
   assert(ph)

   iname = "cluster_" .. name

   -- tbd: use gh here?
   if gv.findsubg(ph, iname) then
      io.stderr:write("graph already has a subgraph " .. name .. " (" .. iname .. ") " .. "\n")
      return false
   end

   local ch = gv.graph(ph, iname)
   set_ndprops(ch)
   gv.setv(ch, "color", param.cs_border_color)
   gv.setv(ch, "style", "bold")

   if param.cs_fillcolor then
      gv.setv(ch, "style", "filled")
      gv.setv(ch, "fillcolor", param.cs_fillcolor)
   end

   -- add invisible dummy node as transition endpoint at boundary of
   -- this composite state
   local dnh = gv.node(ch, name .. "_dummy")
   gv.setv(dnh, "shape", "dot")
   gv.setv(dnh, "fixedsize", "true")
   gv.setv(dnh, "height", "0.0001")
   gv.setv(dnh, "style", "invisible") -- bug in gv, doesn't work
   
   if label then gv.setv(ch, "label", name .. "\n" .. label) end

   dbg("creating new composite state '" .. name .. "' in '" .. parent .. "'")

   return ch
end

-- new transition
function new_tr(gh, srcstr, tgtstr, label)
   
   local sh, shtype = get_shandle(gh, srcstr)
   assert(sh)
   local th, thtype = get_shandle(gh, tgtstr)
   assert(th)

   if shtype == "subgraph" then
      realsh = gv.findnode(sh, srcstr .. "_dummy")
   else
      realsh = sh
   end

   if thtype == "subgraph" then
      realth = gv.findnode(th, tgtstr .. "_dummy")
   else
      realth = th
   end
   
   local eh = gv.edge(realsh, realth)
   set_trprops(eh)

   if shtype == "subgraph" then
      gv.setv(eh, "ltail", "cluster_" .. srcstr)
   end

   if thtype == "subgraph" then
      gv.setv(eh, "lhead", "cluster_" .. tgtstr)
   end

   if label then gv.setv(eh, "label", label) end
end

-- code
gh=new_gra("FSM-1")

new_inista(gh, "fsm1", "initial")
new_finsta(gh, "fsm1", "final")

new_csta(gh, "fsm1", "operational", "entry / stopMotors()\nexit startMotors()")
new_inista(gh, "operational", "initial")
new_sista(gh, "operational", "stopped", "entry / stopMotors()")
new_sista(gh, "operational", "working", "entry / startMotors()")

new_csta(gh, "fsm1", "error", "entry / en_breaks()")
new_inista(gh, "error", "initial")
new_finsta(gh, "error", "final")
new_sista(gh, "error", "hw_err", "entry / handleHWErr()")
new_sista(gh, "error", "sw_err", "entry / handleFault()")

new_csta(gh, "error", "miscerr", "entry / en_breaks()")
new_inista(gh, "miscerr", "initial")
new_finsta(gh, "miscerr", "final")
new_sista(gh, "miscerr", "handle", "entry / handleHWErr()")

new_csta(gh, "operational", "homing", "(parallel state)")
new_csta(gh, "homing", "homingAx1", "")
new_csta(gh, "homing", "homingAx2", "")
new_csta(gh, "homing", "homingAx3", "")

new_inista(gh, "homingAx1", "initial")
new_sista(gh, "homingAx1", "dohomingAx1")
new_finsta(gh, "homingAx1", "final")
new_tr(gh, "homingAx1_initial", "dohomingAx1")
new_tr(gh, "dohomingAx1", "homingAx1_final")

new_inista(gh, "homingAx2", "initial")
new_sista(gh, "homingAx2", "dohomingAx2")
new_finsta(gh, "homingAx2", "final")
new_tr(gh, "homingAx2_initial", "dohomingAx2")
new_tr(gh, "dohomingAx2", "homingAx2_final")

new_inista(gh, "homingAx3", "initial")
new_sista(gh, "homingAx3", "dohomingAx3")
new_finsta(gh, "homingAx3", "final")
new_tr(gh, "homingAx3_initial", "dohomingAx3")
new_tr(gh, "dohomingAx3", "homingAx3_final")

-- toplevel
new_tr(gh, "fsm1_initial", "operational")
new_tr(gh, "operational", "error", "e_error")
new_tr(gh, "error", "operational", "e_recovered")
new_tr(gh, "operational", "fsm1_final", "e_shutdown")
new_tr(gh, "error", "fsm1_final", "e_shutdown")

-- operational
new_tr(gh, "operational_" .. "initial", "stopped")
new_tr(gh, "stopped", "working", "e_start")
new_tr(gh, "working", "stopped", "e_stop")

-- error
new_tr(gh, "error_initial", "hw_err", "[ cur_event('hw_error') ]")
new_tr(gh, "error_initial", "sw_err", "[ cur_event('sw_error') ]")
new_tr(gh, "error_initial", "miscerr", "[ cur_event('misc_error') ]")
new_tr(gh, "hw_err", "error_final", "[ compl('hw_err') ]")
new_tr(gh, "sw_err", "error_final", "[ compl('sw_err') ]")
new_tr(gh, "miscerr", "error_final", "[ compl('miscerr') ]")

-- miscerr
new_tr(gh, "miscerr_initial", "handle", "")
new_tr(gh, "handle", "miscerr_final", "")


print("layouting: ", gv.layout(gh, param.layout))
print("rendering: ", gv.render(gh, param.format, "output." .. param.format))
