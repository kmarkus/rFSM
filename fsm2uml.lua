#!/usr/bin/lua

require("gv")
require("utils")
require("rtfsm")

local pairs, ipairs, print, table, type, assert, gv, io, utils, rtfsm
   = pairs, ipairs, print, table, type, assert, gv, io, utils, rtfsm

module("fsm2uml")

param = {}
param.fontsize = 12.0
param.trfontsize = 7.0
param.ndfontsize = 8.0
param.cs_border_color = "black"
param.cs_fillcolor = "white"
param.layout="dot"
param.rankdir="TD"
param.show_fqn = false

param.err = print
param.warn = print
param.dbg = function () return true end


-- setup common properties
local function set_props(h)
   gv.setv(h, "fixedsize", "false")
   gv.setv(h, "fontsize", param.fontsize)
end

-- setup transition propeties
local function set_trprops(h)
   gv.setv(h, "fixedsize", "false")
   gv.setv(h, "fontsize", param.trfontsize)
   gv.setv(h, "arrowhead", "vee")
   gv.setv(h, "arrowsize", "0.5")
end

-- setup node properties
local function set_ndprops(h)
   gv.setv(h, "fixedsize", "false")
   gv.setv(h, "fontsize", param.ndfontsize)
end

local function setup_color(state, nh)
   gv.setv(nh, "style", "filled")
   if state._mode == 'active' then
      gv.setv(nh, "fillcolor", "green")
   elseif state._mode == 'done' then
      gv.setv(nh, "fillcolor", "chocolate")
   else gv.setv(nh, "fillcolor", "dimgrey") end
end

-- return handle, type for state fqn
local function get_shandle(gh, fqn)

   if fqn == gv.nameof(gh) then return gh, "graph" end

   local sh = gv.findsubg(gh, "cluster_" .. fqn)
   if sh then return sh, "subgraph" end

   local nh = gv.findnode(gh, fqn)
   if nh then return nh, "node" end

   param.err("No state '" .. fqn .. "'")
   return false
end

-- create a new graph
local function new_gra(name, caption)
   local gh = gv.digraph(name)
   caption = caption or ""
   set_props(gh)
   gv.setv(gh, "compound", "true")
   gv.setv(gh, "fontsize", param.fontsize)
   gv.setv(gh, "labelloc", "t")
   gv.setv(gh, "label", name .. '\n' .. caption)
   gv.setv(gh, "remincross", "true")
   gv.setv(gh, "splines", "polyline")
   gv.setv(gh, "rankdir", param.rankdir or "TD")

   -- layout clusters locally before integrating
   -- doesn't seem to make any difference
   -- gv.setv(gh, "clusterrank", "local")

   param.dbg("creating new graph " .. name)
   return gh
end

local function new_conn(gh, conn)
   local ph, type = get_shandle(gh, conn._parent._fqn)
   assert(ph)
   assert(type ~= "simple", "Parent not of type simple")
   assert(rtfsm.is_conn(conn), "Obj not a connector")

   if gv.findnode(ph, conn._fqn) then
      param.err("graph " .. conn._parent._fqn .. "already has a node " .. conn._fqn)
      return false
   end

   local nh = gv.node(ph, conn._fqn)
   set_ndprops(nh)

   if rtfsm.is_junc(conn) then
      if conn._id == 'initial' then
	 gv.setv(nh, "shape", "point")
	 gv.setv(nh, "height", "0.1")
      else
	 gv.setv(nh, "shape", "circle")
	 gv.setv(nh, "height", "0.4")
      end
   elseif rtfsm.is_join(conn) then
      gv.setv(nh, "shape", "Mdiamond")
      gv.setv(nh, "height", "0.3")
   elseif rtfsm.is_fork(conn) then
      gv.setv(nh, "shape", "Mcircle")
      gv.setv(nh, "height", "0.4")
   else param.err("ERROR: unknown conn type")  end

   gv.setv(nh, "label", conn._id)
   gv.setv(nh, "fixedsize", "true")

   param.dbg("creating new conntion " .. conn._fqn)
   return nh
end

-- create a new simple state
local function new_sista(gh, state, label)

   param.dbg("creating new simple state '" .. state._fqn)

   local __label
   local ph, type = get_shandle(gh, state._parent._fqn)
   assert(ph)
   assert(type ~= "simple")

   -- tbd: use gh here?
   if gv.findnode(ph, state._fqn) then
      param.err("graph already has a node " .. state._fqn)
      return false
   end

   local nh = gv.node(ph, state._fqn)
   set_ndprops(nh)

   gv.setv(nh, "style", "rounded")
   gv.setv(nh, "shape", "box")

   setup_color(state, nh)

   if param.show_fqn then __label = state._fqn
   else __label=state._id end

   if label then __label = __label .. "\n" .. label end
   gv.setv(nh, "label", __label)
   return nh
end

-- create an new composite state
local function new_csta(gh, state, label)

   param.dbg("creating new composite state " .. state._fqn)

   local __label
   local ph = get_shandle(gh, state._parent._fqn)
   assert(ph)

   iname = "cluster_" .. state._fqn

   -- tbd: use gh here?
   if gv.findsubg(ph, iname) then
      param.err("graph already has a subgraph " .. state._fqn)
      return false
   end

   local ch = gv.graph(ph, iname)
   set_ndprops(ch)
   gv.setv(ch, "color", param.cs_border_color)
   gv.setv(ch, "style", "bold")
   setup_color(state, ch)

   -- add invisible dummy node as transition endpoint at boundary of
   -- this composite state
   local dnh = gv.node(ch, state._fqn .. "_dummy")
   gv.setv(dnh, "shape", "point")
   gv.setv(dnh, "fixedsize", "true")
   gv.setv(dnh, "height", "0.000001")
   gv.setv(dnh, "style", "invisible") -- bug in gv, doesn't work


   --if label then gv.setv(ch, "label", state._id .. "\n" .. label)
   --else gv.setv(ch, "label", state._id) end

   -- fqn or id?
   if param.show_fqn then __label = state._fqn
   else __label=state._id end

   -- append user label
   if label then __label = __label .. "\n" .. label end
   gv.setv(ch, "label", __label)

   return ch
end

-- new transition
-- src and target are only fully qualified strings!
local function new_tr(gh, src, tgt, events)
   local label

   param.dbg("creating transition from " .. src .. " -> " .. tgt)

   local sh, shtype = get_shandle(gh, src)
   local th, thtype = get_shandle(gh, tgt)

   assert(sh)
   assert(th)

   -- if src/tgt is a cluster then src/tgt is fqn_dummy
   if shtype == "subgraph" then
      realsh = gv.findnode(sh, src .. "_dummy")
   else realsh = sh end

   -- assert(shtype ~= "subgraph")

   -- the following must not happen because transitions *always* end
   -- on a connector or sista.
   assert(thtype ~= "subgraph", "tgt should be a subgraph but isn't: " .. tgt)

   -- if thtype == "subgraph" then realth = gv.findnode(th, tgt .. "_dummy")
   -- else realth = th end
   realth = th

   local eh = gv.edge(realsh, realth)
   set_trprops(eh)

   -- transition stops on composite state boundary
   -- we don't really want to hide the real connections
   if shtype == "subgraph" then
      gv.setv(eh, "ltail", "cluster_" .. src)
   end

   -- if thtype == "subgraph" then
   --    gv.setv(eh, "lhead", "cluster_" .. tgt)
   -- end
   if events then label = table.concat(events, ', ') end
   if label then gv.setv(eh, "label", " " .. label .. " ") end
end


local function proc_node(gh, node)
   if rtfsm.is_csta(node) then new_csta(gh, node)
   elseif rtfsm.is_psta(node) then new_csta(gh, node, "(parallel node)")
   elseif rtfsm.is_sista(node) then new_sista(gh, node)
   elseif rtfsm.is_conn(node) then new_conn(gh, node)
   else
      param.err("unknown node type: " .. node:type() .. ", name=" .. node._fqn)
   end
end

local function proc_trans(gh, t, parent)
   if t.tgt == 'internal' then
      return true
   else
      new_tr(gh, t.src._fqn, t.tgt._fqn, t.events)
   end
end

--
-- convert given fsm to a populated graphviz object
--
local function fsm2gh(root, caption)
   gh = new_gra(root._id, caption)
   rtfsm.mapfsm(function (s) proc_node(gh, s) end, root, rtfsm.is_node)
   rtfsm.mapfsm(function (t, p) proc_trans(gh, t, p) end, root, rtfsm.is_trans)
   return gh
end

function fsm2uml(root, format, outfile, caption)

   if not root._initalized then
      param.err("fsm2uml ERROR: fsm " .. root._id .. " uninitialized")
      return false
   end

   local gh = fsm2gh(root, caption)
   gv.layout(gh, param.layout)
   param.dbg("fsm2uml: running " .. param.layout .. " layouter")
   gv.render(gh, format, outfile)
   param.dbg("fsm2uml: rendering to " .. format .. ", written result to " .. outfile)
end
