#!/usr/bin/lua

require("gv")

local pairs, ipairs, print, table, type, assert, gv, io
   = pairs, ipairs, print, table, type, assert, gv, io

module("fsm2img")

param = {}
param.fontsize = 12.0
param.trfontsize = 7.0
param.ndfontsize = 8.0
param.cs_border_color = "black"
param.cs_fillcolor = "white"
param.layout="dot"

--dbg = function () end
dbg=print


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

local function set_trprops(h)
   gv.setv(h, "fixedsize", "false")
   gv.setv(h, "fontsize", param.trfontsize)
   gv.setv(h, "arrowhead", "vee")
   gv.setv(h, "arrowsize", "0.5")
end

local function set_ndprops(h)
   gv.setv(h, "fixedsize", "false")
   gv.setv(h, "fontsize", param.ndfontsize)
end


-- return handles for different types of states
-- state names must be unique!
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

   dbg("creating new graph " .. name)
   return gh
end

-- create initial state in given parent state
local function new_inista(gh, pstr)

   local ph, type = get_shandle(gh, pstr)
   assert(ph)
   assert(type ~= "simple")
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

-- create final state in given parent
local function new_finsta(gh, pstr)

   local ph,type = get_shandle(gh, pstr)
   assert(ph)
   assert(type ~= "simple")
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
local function new_sista(gh, pstr, name, label)

   local ph,type = get_shandle(gh, pstr)
   assert(ph)
   assert(type ~= "simple")

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
local function new_csta(gh, parent, name, label)

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
   gv.setv(dnh, "shape", "point")
   gv.setv(dnh, "fixedsize", "true")
   gv.setv(dnh, "height", "0.000001")
   gv.setv(dnh, "style", "invisible") -- bug in gv, doesn't work


   if label then gv.setv(ch, "label", name .. "\n" .. label)
   else gv.setv(ch, "label", name) end

   dbg("creating new composite state '" .. name .. "' in '" .. parent .. "'")

   return ch
end

-- new transition
local function new_tr(gh, srcstr, tgtstr, label)
   
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

   if label then gv.setv(eh, "label", " " .. label .. " ") end
   dbg("creating transition from '" .. srcstr .. "' to '" .. tgtstr .. "'")
end


--
-- convert given fsm to a populated graphviz object
-- 

local function proc_state(gh, parent, state)

   -- need a final or initial state?
   if parent.transitions then
      for i,k in ipairs(parent.transitions) do
	 if k.tgt == 'final' then
	    new_finsta(gh, parent.id, 'final')
	    break
	 end
      end

      for i,k in ipairs(parent.transitions) do
	 if k.src == 'initial' then
	    new_inista(gh, parent.id, 'initial')
	    break
	 end
      end
   end

   if state.states then
      local ch = new_csta(gh, parent.id, state.id)
      map(function (s) proc_state(gh, state, s) end, state.states)
   elseif state.parallel then
      local parh = new_csta(gh, parent.id, state.id, "(parallel state)")
      map(function (s) proc_state(gh, state, s) end, state.parallel)
   else
      local sh = new_sista(gh, parent.id, state.id)
   end
end

local function proc_trans(gh, state)
   --if state.initial then
   -- new_tr(gh, state.id .. '_initial', state.initial)
   -- end
   map(function (t) 
	  if t.tgt == 'internal' then
	     return true
	  elseif t.tgt == 'final' then
	     new_tr(gh, t.src, state.id .. '_final', t.event)
	  elseif t.src == 'initial' then
	     new_tr(gh, state.id .. '_initial', t.tgt, t.event)
	  else
	     new_tr(gh, t.src, t.tgt, t.event)
	  end
       end, state.transitions)

   -- map(function (t) proc_trans(gh, state.id, state.states) end, state.states)
   map(function (s) proc_trans(gh, s) end, state.states)
   map(function (s) proc_trans(gh, s) end, state.parallel)
end

local function fsm2gh(root)
   gh = new_gra(root.id)
   --if root.initial then
   --      new_inista(gh, root.id)
   -- end
   map(function (s) proc_state(gh, root, s) end, root.states)

   --   if root.initial then
   --      new_tr(gh, root.id .. '_initial', root.initial)
   --   end

   proc_trans(gh, root)

   return gh
end

function fsm2img(root, format, outfile)
   local gh =fsm2gh(root)
   gv.layout(gh, param.layout)
   dbg("running " .. param.layout .. " layouter")
   gv.render(gh, format, outfile)
   dbg("rendering to " .. format .. ", written result to " .. outfile)
end
