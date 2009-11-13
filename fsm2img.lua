#!/usr/bin/lua

require("gv")
require("fsmutils")

local pairs, ipairs, print, table, type, assert, gv, io, fsmutils
   = pairs, ipairs, print, table, type, assert, gv, io, fsmutils

module("fsm2img")

param = {}
param.fontsize = 12.0
param.trfontsize = 7.0
param.ndfontsize = 8.0
param.cs_border_color = "black"
param.cs_fillcolor = "white"
param.layout="dot"
param.show_fqn = false

dbg = function () end

-- utils
local function map(f, tab)
   local newtab = {}
   if not tab then return newtab end
   for i,v in pairs(tab) do
      res = f(v)
      table.insert(newtab, res)
   end
   return newtab
end


--
-- graphviz convenience wrappers for creating statechart like entities
--

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


-- return handle, type for state fqn
local function get_shandle(gh, fqn)

   if fqn == gv.nameof(gh) then return gh, "graph" end

   local sh = gv.findsubg(gh, "cluster_" .. fqn)
   if sh then return sh, "subgraph" end

   local nh = gv.findnode(gh, fqn)
   if nh then return nh, "node" end

   io.stderr:write("No state '" .. fqn .. "'\n")
   return false
end

-- create a new graph
local function new_gra(name)
   local gh = gv.digraph(name)
   set_props(gh)
   gv.setv(gh, "compound", "true")
   gv.setv(gh, "fontsize", param.fontsize)
   gv.setv(gh, "labelloc", "t")
   gv.setv(gh, "label", name)
   gv.setv(gh, "remincross", "true")
   gv.setv(gh, "splines", "true")
   gv.setv(gh, "rankdir", "TD")

   -- layout clusters locally before integrating
   -- doesn't seem to make any difference
   -- gv.setv(gh, "clusterrank", "local")

   dbg("creating new graph " .. name)
   return gh
end

-- create initial state in given parent state
local function new_inista(gh, parent)

   dbg("creating new initial state in " .. parent.fqn )

   local ph, type = get_shandle(gh, parent.fqn)
   assert(ph)
   assert(type ~= "simple")
   local fqn = parent.fqn .. ".initial"

   if gv.findnode(ph, fqn) then
      io.stderr:write("cstate " .. parent.fqn .. " already has a initial node\n")
      return false
   end

   local nh = gv.node(ph, fqn)
   set_ndprops(n)
   gv.setv(nh, "shape", "point")
   gv.setv(nh, "height", "0.15")

   return nh
end

-- create final state in given parent
local function new_finsta(gh, parent)

   local ph, type = get_shandle(gh, parent.fqn)
   assert(ph)
   assert(type ~= "simple")
   fqn = parent.fqn .. ".final"

   if gv.findnode(ph, fqn) then
      io.stderr:write("graph " .. parent.fqn .. "already has a final node\n")
      return false
   end

   local nh = gv.node(ph, fqn)
   set_ndprops(nh)
   gv.setv(nh, "shape", "doublecircle")
   gv.setv(nh, "label", "")
   gv.setv(nh, "height", "0.1")

   dbg("creating new final state " .. fqn)
   return nh
end

-- create a new simple state
local function new_sista(gh, state, label)

   dbg("creating new simple state '" .. state.fqn)

   local __label
   local ph, type = get_shandle(gh, state.parent.fqn)
   assert(ph)
   assert(type ~= "simple")

   -- tbd: use gh here?
   if gv.findnode(ph, state.fqn) then
      io.stderr:write("graph already has a node " .. state.fqn .. "\n")
      return false
   end

   local nh = gv.node(ph, state.fqn)
   set_ndprops(nh)

   gv.setv(nh, "style", "rounded")
   gv.setv(nh, "shape", "box")

   if param.show_fqn then __label = state.fqn
   else __label=state.id end

   if label then __label = __label .. "\n" .. label end
   gv.setv(nh, "label", __label)
   return nh
end

-- updates until here!

-- create an new composite state
local function new_csta(gh, state, label)

   dbg("creating new composite state " .. state.fqn)

   local __label
   local ph = get_shandle(gh, state.parent.fqn)
   assert(ph)

   iname = "cluster_" .. state.fqn

   -- tbd: use gh here?
   if gv.findsubg(ph, iname) then
      io.stderr:write("graph already has a subgraph " .. state.fqn .. "\n")
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
   local dnh = gv.node(ch, state.fqn .. "_dummy")
   gv.setv(dnh, "shape", "point")
   gv.setv(dnh, "fixedsize", "true")
   gv.setv(dnh, "height", "0.000001")
   gv.setv(dnh, "style", "invisible") -- bug in gv, doesn't work


   --if label then gv.setv(ch, "label", state.id .. "\n" .. label)
   --else gv.setv(ch, "label", state.id) end

   if param.show_fqn then __label = state.fqn
   else __label=state.id end

   if label then __label = __label .. "\n" .. label end
   gv.setv(nh, "label", __label)

   return ch
end

-- new transition
-- src and target are only fully qualified strings!
local function new_tr(gh, src, tgt, label)

   dbg("creating transition from '" .. src .. "' to '" .. tgt .. "'")

   local sh, shtype = get_shandle(gh, src)
   local th, thtype = get_shandle(gh, tgt)

   assert(sh)
   assert(th)

   -- if src/tgt is a cluster then src/tgt is fqn_dummy
   if shtype == "subgraph" then realsh = gv.findnode(sh, src .. "_dummy")
   else realsh = sh end

   if thtype == "subgraph" then realth = gv.findnode(th, tgt .. "_dummy")
   else realth = th end

   local eh = gv.edge(realsh, realth)
   set_trprops(eh)

   -- transition stops on composite state boundary
   if shtype == "subgraph" then
      gv.setv(eh, "ltail", "cluster_" .. src)
   end

   if thtype == "subgraph" then
      gv.setv(eh, "lhead", "cluster_" .. tgt)
   end

   if label then gv.setv(eh, "label", " " .. label .. " ") end
end


local function has_initial_tr(transitions)
   for i,k in ipairs(transitions) do
      if k.src == 'initial' then
	 return true end end
   return false
end

local function has_final_tr(transitions)
   for i,k in ipairs(transitions) do
      if k.tgt == 'final' then
	 return true end end
   return false
end


local function proc_state(gh, state)
   if state.states then -- composite state?
      new_csta(gh, state)
   elseif state.parallel then -- parallel state?
      new_csta(gh, state, "(parallel state)")
   else -- simple state
      new_sista(gh, state)
   end

   -- need a final or initial state?
   if state.transitions then
      if has_initial_tr(state.transitions) then
	 new_inista(gh, state)
      end
      if has_final_tr(state.transitions) then
	 new_finsta(gh, state)
      end
   end
end

local function proc_trans(gh, t, parent)
   if t.tgt == 'internal' then
      return true
   elseif t.tgt == 'final' then
      new_tr(gh, t.src.fqn, parent.fqn .. '.final', t.event)
   elseif t.src == 'initial' then
      new_tr(gh, parent.fqn .. '.initial', t.tgt.fqn, t.event)
   else
      new_tr(gh, t.src.fqn, t.tgt.fqn, t.event)
   end
end

--
-- convert given fsm to a populated graphviz object
--

local function fsm2gh(root)
   gh = new_gra(root.id)

   if root.transitions then
      if has_initial_tr(root.transitions) then
	 new_inista(gh, root)
      end
      if has_final_tr(root.transitions) then
	 new_finsta(gh, root)
      end
   end

   fsmutils.map_state(function (s) proc_state(gh, s) end, root)
   fsmutils.map_trans(function (t, p) proc_trans(gh, t, p) end, root)
   return gh
end

function fsm2img(root, format, outfile)

   if not root.__initalized then
      param.err("fsm2img ERROR: fsm " .. root.id .. " uninitialized")
      return false
   end

   local gh = fsm2gh(root)
   gv.layout(gh, param.layout)
   dbg("fsm2img: running " .. param.layout .. " layouter")
   gv.render(gh, format, outfile)
   dbg("fsm2img: rendering to " .. format .. ", written result to " .. outfile)
end
