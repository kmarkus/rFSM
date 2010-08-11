--
-- This file is part of rFSM.
--
-- rFSM is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- rFSM is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
-- License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with rFSM.  If not, see <http://www.gnu.org/licenses/>.
--

require ('utils')

-- tbdel for release!!
-- require ('luarocks.loader')
-- require('std')

-- save references

local param, pairs, ipairs, print, tostring, table, string, type,
loadstring, assert, coroutine, setmetatable, getmetatable, utils, io,
unpack = param, pairs, ipairs, print, tostring, table, string, type,
loadstring, assert, coroutine, setmetatable, getmetatable, utils, io,
unpack

module("rfsm")

local map = utils.map

--------------------------------------------------------------------------------
-- Model Elements and generic helper functions
--------------------------------------------------------------------------------

-- simple state
--
-- required: -
-- optional: entry, doo, exit
sista = {}
function sista:type() return 'simple' end
function sista:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end

--
-- composite state
--
-- required: -
-- optional: entry, exit, states, transitions
-- disallowed: doo
-- 'root' is a composite state which requires an 'initial' connector
csta = {}
function csta:type() return 'composite' end
function csta:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end

--
-- parallel state
--
-- required: --
-- optional: composite states, parallel states, connectors, join, fork
-- disallowed: simple_state
psta = {}
function psta:type() return 'parallel' end
function psta:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end

--
-- transition
--
trans = {}

function trans:type() return 'transition' end

function trans:__tostring()
   local src, tgt, event = "none", "none", "none"

   if self.src then
      if type(self.src) == 'string' then
	 src = self.src
      else src = self.src._fqn end
   end

   if self.tgt then
      if type(self.tgt) == 'string' then tgt = self.tgt
      else tgt = self.tgt._fqn end
   end
   return "T={ src='" .. src .. "', tgt='" .. tgt .. "', event='" .. tostring(self.event) .. "' }"
end

function trans:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end

--
-- junction
--
junc = {}
function junc:type() return 'junction' end
function junc:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end

--
-- fork
--
fork = {}
function fork:type() return 'fork' end
function fork:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end

--
-- join
--
join = {}
function join:type() return 'join' end
function join:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end

-- usefull predicates
function is_fsmobj(s)
   if type(s) ~= 'table' then
      return false
   end
   local mt = getmetatable(s)
   if mt and  mt.__index then
      return true
   else
      fsm.err("ERROR: no fsmobj: " .. table.foreach(s, print) .. " (interesting!)")
      return false
   end
end

function is_sista(s) return is_fsmobj(s) and s:type() == 'simple' end
function is_csta(s)  return is_fsmobj(s) and s:type() == 'composite' end
function is_psta(s)  return is_fsmobj(s) and s:type() == 'parallel' end
function is_trans(s) return is_fsmobj(s) and s:type() == 'transition' end
function is_junc(s)  return is_fsmobj(s) and s:type() == 'junction' end
function is_join(s)  return is_fsmobj(s) and s:type() == 'join' end
function is_fork(s)  return is_fsmobj(s) and s:type() == 'fork' end

function is_sta(s)   return is_sista(s) or is_csta(s) or is_psta(s) end
function is_cplx(s)  return is_csta(s) or is_psta(s) end
function is_node(s)  return is_sta(s) or is_conn(s) end
function is_conn(s)  return is_junc(s) or is_fork(s) or is_join(s) end
function is_pconn(s) return is_fork(s) or is_join(s) end

function fsmobj_tochar(obj)
   if not is_fsmobj(obj) then return end
   return string.upper(string.sub(obj:type(), 1, 1))
end

-- check if a table key is metadata (for now starts with a '_')
function is_meta(key) return string.sub(key, 1, 1) == '_' end

-- check if src is connected to tgt by a transition
local function is_connected(src, tgt)
   assert(src._otrs, "ERR, is_connected: no ._otrs table found")
   for _,t in pairs(src._otrs) do
      if t.tgt._fqn == tgt._fqn then return true end
   end
   return false
end

-- apply func to all fsm elements for which pred returns true
-- depth is maxdepth to enter (nil
function mapfsm(func, fsm, pred, depth)
   local res = {}
   local depth = depth or -1

   local function __mapfsm(states)
      map(function (s, k)
	     if depth == 0 then return end
	     -- ugly: ignore entries starting with '_'
	     if not is_meta(k) then
		if pred(s) then
		   res[#res+1] = func(s, states, k)
		end
		if is_cplx(s) then
		   depth = depth - 1
		   __mapfsm(s)
		end
	     end
	  end, states)
   end
   __mapfsm(fsm)
   return res
end

-- execute func on all vertical states between from and to
-- from must be a child of to (for now)
function map_from_to(fsm, func, from, to)
   local walker = from
   local res = {}
   while from ~= to do
      res[#res+1] = func(fsm, walker)
      walker = walker._parent
   end
   return res
end

----------------------------------------
-- helper function for dynamically modifying fsm
-- add obj with id under parent
-- tbd: should reuse the initalization functions like add_otrs...
-- whereever possible!
function fsm_merge(fsm, parent, obj, id)

   -- do some checking
   local mes = {}
   if not is_cplx(parent) then
      mes[#mes+1] = "parent " .. parent._fqn .. " of " .. id .. " not a complex state"
   end
   if id ~= nil and parent[id] ~= nil then
      mes[#mes+1] = "parent " .. parent._fqn .. " already contains a sub element " .. id
   end

   if not is_trans(obj) and id == nil then
      mes[#mes+1] = "requested to merge node object without id"
   end

   if is_trans(obj) and not is_node(obj.src) and not is_node(obj.tgt) then
      mes[#mes+1] = "trans src or tgt is not a node: " .. tostring(obj)
   end

   if #mes > 0 then
      fsm.err("ERROR: merge failed: ", table.concat(mes, '\n\t'))
      return false
   end

   -- merge the object
   if is_sista(obj) or is_conn(obj) then
      parent[id] = obj
      obj._parent = parent
      obj._id = id
      obj._fqn = parent._fqn ..'.' .. id
      -- tbd: update otrs?
   elseif is_trans(obj) then
      parent[#parent+1] = obj
      obj.src._otrs[#obj.src._otrs+1] = obj
      if is_join(obj.tgt) then
	 obj.tgt._itrs[#obj.tgt._itrs+1] = obj
      end
   else
      fsm.err("ERROR: merging of " .. obj:type() .. " objects not implemented (" .. id .. ")")
      return false
   end

   return true
end

--------------------------------------------------------------------------------
-- Initialization functions for preprocessing and validating the FSM
--------------------------------------------------------------------------------

----------------------------------------
-- construct parent links
-- this modifies fsm

local function add_parent_links(fsm)
   fsm._parent = fsm
   mapfsm(function (s, p) s._parent = p end, fsm, is_node)
end

----------------------------------------
-- add id fields
local function add_ids(fsm)
   mapfsm(function (s,p,n) s._id = n end, fsm, is_node)
end

----------------------------------------
-- add fully qualified names (fqn) to node types
-- depends on parent links beeing available
local function add_fqns(fsm)
   function __add_fqn(s, p)
      if not s._id then
	 fsm.err("ERROR: state (" .. s:type() .. ") without id, parent: " .. p._fqn)
      end
      s._fqn = p._fqn .. "." .. s._id
   end

   fsm._fqn = fsm._id
   mapfsm(__add_fqn, fsm, is_node)
end

----------------------------------------
-- be nice: add default connectors so that the user doesn't not have
-- to do this boring job
local function add_defconn(fsm)

   -- if initial (fork) or final (join) doesn't exist then create them
   -- and add transitions to all initial composite states
   local function __add_psta_defconn(psta, parent, id)
      if not psta.initial then
	 assert(fsm_merge(fsm, psta, fork:new{}, 'initial'))
	 fsm.info("INFO: created undeclared fork " .. psta.initial._fqn)

	 -- add all non-existing transitions from initial-fork to all
	 -- toplevel csta children. But as otrs are not built yet this
	 -- means having to resolve paths manually. Therefore postpone
	 -- until transitions are resolved.
      end
      if not psta.final then
	 assert(fsm_merge(fsm, psta, join:new{}, 'final'))
	 fsm.info("INFO: created undeclared join " .. psta.final._fqn)
	 -- add transition later: see above comment.
      end
   end

   -- if transition *locally* references a non-existant initial or
   -- final connector create it
   local function __add_trans_defconn(tr, p)
      if is_csta(p) then
	 if tr.src == 'initial' and p.initial == nil then
	    fsm_merge(fsm, p, junc:new{}, 'initial')
	    fsm.info("INFO: created undeclared connector " .. p._fqn .. ".initial")
	 end
	 if tr.tgt == 'final' and p.final == nil then
	    fsm_merge(fsm, p, junc:new{}, 'final')
	    fsm.info("INFO: created undeclared connector " .. p._fqn .. ".final")
	 end
      end
   end

   mapfsm(__add_psta_defconn, fsm, is_psta)
   mapfsm(__add_trans_defconn, fsm, is_trans)
end

----------------------------------------
-- add transitions from parallel-state-initial-fork-connector to all
-- toplevel composite states (regions)
-- only after resolving transitons
local function add_psta_trans(fsm)

   -- transitions from initial (fork) to regions
   local function __add_psta_itrans(psta, parent, id)
      -- determine list of regions which are not connected by initial
      -- tbd: replace this my a mapfsm with maxdepth param
      local reg = utils.filter(
	 function (r,k)
	    if not is_meta(k) and is_cplx(r) and not is_connected(psta.initial, r) then
	       return true
	    end
	    return false
	 end, psta)

      utils.map(function (r)
		   fsm.dbg("\t adding transition " .. psta.initial._fqn .. " -> " .. r.initial._fqn)
		   return fsm_merge(fsm, psta, trans:new{ src=psta.initial, tgt=r.initial } )
		end, reg)
   end

   -- transitions from regions to final (join)
   local function __add_psta_ftrans(psta, parent, id)
      -- determine list of regions which are not connected to final fork
      -- tbd: replace this my a mapfsm with maxdepth param
      local reg = utils.filter(
	 function (r,k)
	    if not is_meta(k) and is_cplx(r) and not is_connected(r, psta.final) then
	       return true
	    end
	    return false
	 end, psta)

      utils.map(function (r)
		 fsm.dbg("\t adding transition " .. r._fqn .. " -> " .. psta.final._fqn)
		 return fsm_merge(fsm, psta, trans:new{ src=r, tgt=psta.final } )
	      end, reg)
   end

   fsm.info("INFO: creating undeclared parallel state transitions")

   return utils.andt(mapfsm(__add_psta_itrans, fsm, is_psta),
		     mapfsm(__add_psta_ftrans, fsm, is_psta))
end

----------------------------------------
-- build a table for each node of all outgoing transitions in node._otrs
local function add_otrs(fsm)
   mapfsm(function (nd)
	     if nd._otrs == nil then nd._otrs={} end
	  end, fsm, is_node)

   mapfsm(function (tr, p)
	     table.insert(tr.src._otrs, tr)
	  end, fsm, is_trans)
end

----------------------------------------
-- build a table for each join of all incoming transitions in node._itrs
local function add_itrs(fsm)
   mapfsm(function (jn)
	     if jn._itrs == nil then jn._itrs={} end
	  end, fsm, is_join)

   mapfsm(function (tr, p)
	     if is_join(tr.tgt) then
		table.insert(tr.tgt._itrs, tr)
	     end
	  end, fsm, is_trans)
end

----------------------------------------
-- resolve path function
-- turn string state into the real thing
local function __resolve_path(fsm, state_str, parent)

   -- index tree with array tab
   local function index_tree(tree, tab, mes)
      local res = tree
      for _, k in ipairs(tab) do
	 res = res[k]
	 if not res then
	    mes = "no " .. k .. " in " .. table.concat(tab, ".")
	    break
	 end
      end
      return res
   end

   local state, mes
   if not string.find(state_str, '[\\.]') then
      -- no dots, local state
      state = parent[state_str]
      if state == nil then
	 mes = "no " .. state_str .. " in " .. parent._fqn
      end
   elseif string.sub(state_str, 1, 1) == '.' then
      -- leading dot, relative target
      fsm.err("ERROR: relative transitions (leading dot) not yet supported: " .. state_str)
   else
      -- absolute target, this is a fqn!
      state = index_tree(fsm, utils.split(state_str, "[\\.]"), mes)
   end
   return state, mes
end

----------------------------------------
-- resolve transition src and target strings into references of the real states
--    depends on fully qualified names
local function resolve_trans(fsm)

   -- three types of targets:
   --    1. local, only name given, no '.'
   --    2. relative, leading dot
   --    3. absolute, no leading dot

   -- resolve transition src
   local function __resolve_src(tr, parent)
      local src, mes = __resolve_path(fsm, tr.src, parent)
      if not src then
	 fsm.err("ERROR: resolving src failed " .. tostring(tr) .. ": " .. mes)
	 return false
      else
	 tr.src = src
      end
      return true
   end

   -- resolve transition tgt
   local function __resolve_tgt(tr, parent)
      -- resolve target
      if tr.tgt == 'internal' then
	 fsm.warn("WARNING: internal events not supported (yet)")
	 return true
      end

      local tgt, mes = __resolve_path(fsm, tr.tgt, parent)

      if not tgt then
	 fsm.err("ERROR: resolving tgt failed " .. tostring(tr) .. ": " .. mes )
	 return false
      else
	 -- complex state, connect to 'initial'
	 if is_cplx(tgt) then
	    if tgt.initial == nil then
	       fsm.err("ERROR: transition " .. tostring(tr) ..
		      " ends on cstate without initial connector")
	       return false
	    else
	       tr.tgt = tgt.initial
	    end
	 else
	    tr.tgt = tgt
	 end
      end
      return true
   end

   local function __resolve_trans(tr, parent)
      return __resolve_src(tr, parent) and __resolve_tgt(tr, parent)
   end

   return utils.andt(mapfsm(__resolve_trans, fsm, is_trans))
end


-- get least common parallel ancestor and orthogonal regions within
-- LCPA of of s1 and s2 (inefficient!)
-- returns lcpa, ortreg(s1) and ortreg(s2)
--
-- Only for static validation:
-- a transition to a different region within the same LCPA is invalid
local function getLCPA(fsm, s1, s2)
   -- returns an array
   local function walk_up(fsm, s)
      local up_path = {}
      local walker = s
      while walker ~= fsm do
	 table.insert(up_path, 1, walker)
	 walker = walker._parent
      end
      return up_path
   end

   local function max(a,b)
      if a>b then return a else return b end
   end

   -- if we are given connectors, take the parent state otherwise
   -- forks/joins will be understood as seperated orthogonal regions

   assert(is_node(s1), "s1 not a node: ", tostring(s1))
   assert(is_node(s2), "s2 not a node: ", tostring(s2))

   local ups1 = walk_up(fsm, s1)
   local ups2 = walk_up(fsm, s2)

   -- the last identical is the LCPA, the first differing the
   -- orthogonal regions ?!?!? GRAAA!
   for i = 2,max(#ups1, #ups2) do
      if ups1[i-1] == ups2[i-1] and
	 is_psta(ups1[i-1]) and is_csta(ups1[i]) and is_csta(ups2[i]) then
	 return ups1[i-1], ups1[i], ups2[i]
      end
   end
   return false
end



----------------------------------------
-- perform some early validation (before transitions are resolved)
-- test should bark loudly about problems and return false if
-- initialization is to fail
-- depends on parent links for more useful output
function verify_early(fsm)
   local mes, res = {}, true

   local function check_node(s, p)
      local ret = true
      -- all nodes have a parent which is a node
      if not p then
	 fsm.err("ERROR: parent of " .. s._fqn .. " is nil")
	 ret = false
      end

      if not is_node(p) then
	 fsm.err("ERROR: parent of " .. s._fqn .. " is not a node but of type " .. p:type())
	 ret = false
      end

      return ret
   end

   local function check_csta(s, p)
      local ret = true
      if s.initial and not is_junc(s.initial) then
	 fsm.err("ERROR: in composite " .. s.initial._fqn .. " is not of type junction but " .. s.initial:type())
	 ret = false
      end
      if s.final and not is_junc(s.final) then
	 fsm.err("ERROR: in composite " .. s.final._fqn .. " is not of type junction but " .. s.initial:type())
	 ret = false
      end
      return ret
   end

   -- validate parallel states
   local function check_psta(s, p)
      local ret = true
      -- initial and final must be fork and join
      if s.initial and not is_fork(s.initial) then
	 mes[#mes+1] = "ERROR: parallel " .. s.initial._fqn .. " initial is not a fork but " .. s.initial:type()
	 ret = false
      end

      if s.initial and not is_join(s.final) then
	 mes[#mes+1] = "ERROR: parallel " .. s.initial._fqn .. " final is not a join but " .. s.initial:type()
	 ret = false
      end

      -- assert that all child states are complex
      return ret
   end

   -- validate complex states
   local function check_cplx(s, parent)
      if s.doo then
	 mes[#mes+1] = "WARNING: " .. s .. " 'doo' function in csta will never run"
      else
	 return true
      end
   end

   -- validate transitions
   local function check_trans(t, p)
      local ret = true
      if not t.src then
	 mes[#mes+1] = "ERROR: " .. tostring(t) .." missing src state, parent='" .. p._fqn .. "'"
	 ret = false
      end
      if not t.tgt then
	 mes[#mes+1] = "ERROR: " .. tostring(t) .." missing tgt state, parent='" .. p._fqn .. "'"
	 ret = false
      end

      if not type(t.events) == 'table' then
	 mes[#mes+1] = "ERROR: " .. tostring(t) .." 'events' field must be a table"
	 ret = false
      end

      if t.event then
	 mes[#mes+1] = "WARNING: " .. tostring(t) .." 'event' field undefined, did you mean 'events'?"
      end

      -- tbd event
      return ret
   end

   -- validate parallel connectors fork and join
   local function check_pconn(fj, p)
      local ret = true
      -- parent of fork/join must be a psta!
      if not is_psta(p) then
	 mes[#mes+1] = "ERROR: parent " .. p._fqn .. " of fork/join" .. fj._fqn .. " is not a parallel state"
	 ret = false
      end
      return ret
   end

   local function check_junc(j, p)
      -- parent of junction must be a csta!
      local ret = true
      if not is_csta(p) then
	 mes[#mes+1] = "ERROR: parent " .. p._fqn .. " of junction " .. j._fqn .. "is not a composite state"
	 ret = false
      end
      return ret
   end

   -- root
   if not is_csta(fsm)  then
      mes[#mes+1] = "ERROR: fsm not a composite state but of type " .. fsm:type()
      res = false
   end

   if fsm.initial == nil then
      mes[#mes+1] = "ERROR: fsm " .. fsm._id .. " without initial junction"
      res = false
   end

   -- no side effects, order does not matter
   res = res and utils.andt(mapfsm(check_node, fsm, is_node))
   res = res and utils.andt(mapfsm(check_cplx, fsm, is_cplx))
   res = res and utils.andt(mapfsm(check_csta, fsm, is_csta))
   res = res and utils.andt(mapfsm(check_psta, fsm, is_psta))
   res = res and utils.andt(mapfsm(check_trans, fsm, is_trans))
   res = res and utils.andt(mapfsm(check_pconn, fsm, is_pconn))
   res = res and utils.andt(mapfsm(check_junc, fsm, is_junc))

   return res, mes
end

----------------------------------------
-- late checks
-- must run after transitions are resolved
function verify_late(fsm)
   local mes, res = {}, true

   local function check_trans(t, p)
      local ret = true

      local lcpa, orsrc, ortgt = getLCPA(fsm, t.src, t.tgt)
      if lcpa and orsrc ~= ortgt then
	 mes[#mes+1] = "ERROR: invalid transition" .. tostring(t) .." src and tgt are in different regions of parallel " .. lcpa._fqn
	 ret = false
      end

      return ret
   end

   res = res and utils.andt(mapfsm(check_trans, fsm, is_trans))
   return res, mes
end

function check_no_otrs(fsm)
   local function __check_no_otrs(s, p)
      if s._otrs == nil then
	 fsm.warn("WARNING: no outgoing transitions from node '" .. s._fqn .. "'")
	 return false
      else return true end
   end
   return utils.andt(mapfsm(__check_no_otrs, fsm, is_node))
end

----------------------------------------
-- set log/printing functions to reasonable defaults
-- levels(default): err(true), warn(true), info(true), dbg(false)
-- values: 1) function that takes variable args
--         2) true: print with default
--         3) false: disable
local function setup_printers(fsm)

   local function __null_func() return end

   local function setup_printer(def, p)
      if fsm[p] == false then
	 fsm[p] = __null_func
      elseif fsm[p] == nil then
	 fsm[p] = def
      elseif fsm[p] == true then
	 fsm[p] = utils.stdout
      elseif type(fsm[p]) ~= 'function' then
	 print("unknown printer: " .. tostring(p))
	 fsm[p] = def
      end
   end
   utils.foreach(setup_printer, { err=utils.stderr, warn=utils.stderr,
				  info=utils.stdout, dbg=utils.stdout } )
end

----------------------------------------
-- create a state -> outgoing transition lookup cache
-- move to otrs field in state
-- local function st2otr_cache(fsm)
--    local cache = {}

--    map_trans(function (tr, parent)
-- 		if not cache[tr.src] then cache[tr.src] = {} end
-- 		table.insert(cache[tr.src], tr)
-- 	     end, fsm)

--    return function(srcfqn) return cache[srcfqn] end
-- end
----------------------------------------
-- initialize fsm
-- create parent links
-- create table for lookups
function init(fsm_templ, name)

   assert(is_csta(fsm_templ), "invalid fsm model passed to rfsm.init")

   local fsm = utils.deepcopy(fsm_templ)

   -- fsm._id = name or 'root'
   fsm._id = 'root'

   setup_printers(fsm)

   add_parent_links(fsm)
   add_ids(fsm)
   add_fqns(fsm)
   add_defconn(fsm)

   -- verify (early)
   local ret, errs = verify_early(fsm)

   -- don't fail on warnings
   if #errs > 0 then
      fsm.err(table.concat(errs, '\n'))
      if not ret then return false end
   end

   if not resolve_trans(fsm) then
      fsm.err("ERROR: failed to resolve transitions of fsm " .. fsm._id)
      return false
   end

   -- verify (late)
   local ret, errs = verify_late(fsm)
   if not ret then fsm.err(table.concat(errs, '\n')) return false end

   -- add outgoing transition table
   add_otrs(fsm)

   -- add incoming transition table for joins
   add_itrs(fsm)

   -- add missing parallel transitions
   if not add_psta_trans(fsm) then return false end

   check_no_otrs(fsm)
   fsm._act_leaves = {}


   -- internal event queue is empty
   fsm._intq = { 'e_init_fsm' }

   -- getevents user hook supplied?
   -- must return a table with events
   if not fsm.getevents then
      fsm.getevents = function () return {} end
   end

   if not fsm.drop_events then
      fsm.drop_events =
	 function (events)
	    if #events>0 then fsm.dbg("DROPPING_EVENTS", events) end end
   end

   -- All OK!
   fsm._initalized = true
   return fsm
end



--------------------------------------------------------------------------------
-- Operational Functions
--------------------------------------------------------------------------------

----------------------------------------
-- send events to the local fsm event queue
function send_events(fsm, ...)
   fsm.dbg("RAISED", table.concat(arg, ", "))
   for _,v in ipairs(arg) do
      table.insert(fsm._intq, v)
   end
end


-- this function exploits the fact that the LCA is the first parent of
-- tgt which is in state 'active'
-- sure this works for parallel states? yes!
local function getLCA(fsm, tr)
   -- source path lookup table
   local src_path_lt = {}

   local walker = tr.src._parent
   while true do
      src_path_lt[walker] = true
      if walker == fsm then break end
      walker = walker._parent
   end

   walker = tr.tgt._parent

   while not src_path_lt[walker] do
      walker = walker._parent
   end
   return walker
end

--
-- compute the implicit paths of transition tr: this is the up path
-- from tr.src up to (but excluding LCA) and the down path from LCA
-- (excluded) to tr.tgt
--
local function tr_ipath(fsm, tr)
   local lca = getLCA(fsm, tr)
   local up_path = {}
   local down_path = {}
   local walker

   -- up ...
   walker = tr.src
   while walker ~= lca do
      up_path[#up_path+1] = walker
      walker = walker._parent
   end

   -- and down
   walker = tr.tgt
   while walker ~= lca do
      down_path[#down_path+1] = walker
      walker = walker._parent
   end

   return lca, up_path, down_path
end


-- get parallel parent
local function getPParent(fsm, node)
   local walker = node.parent

   while walker ~= fsm do
      if is_psta(walker) then return walker end
   end
   return false
end


----------------------------------------
-- merge all external and internal events into list
local function getallev(fsm)
   local extq = fsm.getevents()
   local res = fsm._intq
   fsm._intq = {}

   for _,v in ipairs(extq) do
      table.insert(res, v)
   end
   return res
end

local function actleaf_add(fsm, lf)
   table.insert(fsm._act_leaves, lf)
   fsm.dbg("ACT_LEAF_ADD", lf._fqn, ", cur:",
	   map(function(al) return al._fqn end, fsm._act_leaves))
end

local function actleaf_rm(fsm, lf)
   for i=1,#fsm._act_leaves do
      if fsm._act_leaves[i] == lf then
	 table.remove(fsm._act_leaves, i)
	 fsm.dbg("ACT_LEAF_RM", lf._fqn, ", cur:",
		 map(function(al) return al._fqn end, fsm._act_leaves))
      end
   end
end

----------------------------------------
-- actchild handling
local function actchild_add(parent, child)
   if parent._actchild == nil then
      parent._actchild = { [child] = true }
   else
      parent._actchild[child] = true
   end
end

local function actchild_rm(parent, child)
   if parent._actchild ~= nil then
      parent._actchild[child] = nil
   end
end

local function actchild_get(state)
   if not state._actchild then return {}
   else return state._actchild end
end

-- set or get state mode
function sta_mode(s, m)
   assert(is_sta(s), "can't set_mode on non state type")
   if m then
      assert(m=='active' or m=='inactive' or m=='done')
      s._mode = m
      if m=='inactive' then actchild_rm(s._parent, s)
      elseif m=='active' then actchild_add(s._parent, s)
      else
	 -- in 'done' it should be active already
	 assert(s._parent._actchild[s], "sta_mode: ERROR: 'done' but not actchild of parent")
      end
   end
   return s._mode
end

----------------------------------------
-- run one doo functions of an active state and place it at the end of
-- the active queue
-- active_leaf states might not have a doo function, so check
-- returns true if there is at least one active doo, otherwise false
local function run_doos(fsm)
   local has_run = false

   for i = 1,#fsm._act_leaves do
      -- rotate
      local state = table.remove(fsm._act_leaves, 1)
      table.insert(fsm._act_leaves, state)

      -- create new coroutine
      if state.doo and not state._doo_co then
	 fsm.dbg("DOO", "created coroutine for " .. state._fqn .. " doo")
	 state._doo_co = coroutine.create(state.doo)
      end

      -- corountine still active, can be resumed
      if state._doo_co and  coroutine.status(state._doo_co) == 'suspended' then
	 coroutine.resume(state._doo_co, fsm, state, 'doo')
	 has_run = true
	 if coroutine.status(state._doo_co) == 'dead' then
	    state._doo_co = nil
	    sta_mode(state, 'done')
	    actleaf_rm(fsm, state)
	    send_events(fsm, "e_done@" .. state._fqn)
	    fsm.dbg("DOO", "removing completed coroutine of " .. state._fqn .. " doo")
	 end
	 break
      end
   end

   return has_run
end

----------------------------------------
-- enter a state (and nothing else)
local function enter_one_state(fsm, state)

   if not is_sta(state) then return end

   sta_mode(state, 'active')

   if state.entry then state.entry(fsm, state, 'entry') end

   if is_sista(state) then
      if state.doo then actleaf_add(fsm, state)
      else sta_mode(state, "done") end
   end

   fsm.dbg("STATE_ENTER", state._fqn)
end

----------------------------------------
-- exit a state (incl all substates)
local function exit_state(fsm, state)

   -- if complex exit child states first
   if is_cplx(state) then
      for ac,_ in pairs(actchild_get(state)) do
	 exit_state(fsm, ac)
      end
   end

   if is_sta(state) then
      -- save this for possible history entry
      if sta_mode(state) == 'active' then
	 state._parent._last_active = state
      else
	 state._parent._last_active = false
      end

      sta_mode(state, 'inactive')
      if state.exit then state.exit(fsm, state, 'exit') end
      if is_sista(state) then actleaf_rm(fsm, state) end
   end

   fsm.dbg("STATE_EXIT", state._fqn)
end


----------------------------------------
-- simple transition consists of three parts:
--  1. exec up to LCA
--  2. run effect
--  3a. implicit entry of parents of tgt
--  3b. explicit entry of tgt

-- optional runtime checks
local function exec_trans_check(fsm, tr)
   local res = true
   if tr.tgt._mode ~= 'inactive' then
      fsm.err("ERROR", "transition target " .. tr.tgt._fqn .. " in invalid state '" .. tr.tgt._mode .. "'")
      res = false
   end
   return res
end


-- Execute Part 1 of the transition tr, which means exiting the src
-- state (incl. active child states) and up to but excluding the LCA
-- of src and tgt.
local function __exec_trans_exit(fsm, tr, lca, up_path)

   -- observation: the LCA can _never_ be a parallel state, as that
   -- would mean transitioning between regions. The LCA can also never
   -- be a simple state. -> It must be composite. As a consequence it
   -- can have at most one active child.
   --
   -- above is wrong. i.e. there can exist a valid transition from
   -- initial-fork to one of the csta in the psta.

   -- if not is_csta(lca) then
   -- fsm.err("ERROR", "exec_trans_exit: lca" .. lca._fqn .. " not a csta.")
   -- end

   -- LCA can have no active child when:
   --   - initial transition
   --   - transitions between junctions of same scope

   -- but none of these affect the other regions of the psta: these
   -- are only exited when the psta is exited itself. But in that case
   -- the LCA is not the psta.
   --
   -- Cleanest solution: just exit the last (and thus highest) state
   -- in the up_path.

   -- up and down should at least include tr.src and tr.tgt
   assert(#up_path >= 1)

   fsm.dbg("TRANS_EXIT", "exiting all up to (including):", up_path[#up_path]._fqn, ", lca:", lca._fqn)
   exit_state(fsm, up_path[#up_path])
end

local function exec_trans_exit(fsm, tr)
   local lca, up_path, down_path = tr_ipath(fsm, tr)
   __exec_trans_exit(fsm, tr, lca, up_path)
end

-- Execute Part 2 of the transition: the effect
local function exec_trans_effect(fsm, tr)
   -- run effect
   fsm.dbg("EFFECT", tostring(tr))
   if tr.effect then
      tr.effect(tr)
   end
end

-- Execute Part 3 of the transition: implicit enter all states to
-- trans_target (excluding the already active LCA).
--
-- tbd: how does this deal with implicit entries of pstates?
local function __exec_trans_enter(fsm, tr, lca, down_path)
   assert(#down_path >= 1)
   fsm.dbg("TRANS_ENTER", "lca: " .. lca._fqn, "down_path: ",
	   table.concat(map(function (s) return s._fqn end, down_path), " > "))
   -- now enter down_path
   while #down_path > 0 do
      enter_one_state(fsm, table.remove(down_path))
   end
end

local function exec_trans_enter(fsm, tr)
   local lca, up_path, down_path = tr_ipath(fsm, tr)
   __exec_trans_enter(fsm, tr, lca, down_path)
end

-- Do all in one:
-- can't fail in any way
--
local function exec_trans(fsm, tr)
   local lca, up_path, down_path = tr_ipath(fsm, tr)
   __exec_trans_exit(fsm, tr, lca, up_path)
   exec_trans_effect(fsm, tr)
   __exec_trans_enter(fsm, tr, lca, down_path)
end


----------------------------------------
-- pretty print path
-- path = pnode.next[1]->pnode.next[1]->pnode
--                        .next[1]->pnode.next[1] = true
--                        .next[2]->pnode.next[1] = true
-- pnode = { pnode=join/fork, next={seg1, seg2, ... }
-- seg = { trans=transition, next=pnode }

local function path2str(path, indc, indmul)
   indc = indc or ' '
   indmul = indmul or 2
   local strtab = {}

   local function __path2str(pnode, ind)
      strtab[#strtab+1] = pnode.node._fqn
      strtab[#strtab+1] = '[' .. fsmobj_tochar(pnode.node) .. ']'
      if not pnode.nextl then return end

      if is_fork(pnode.node) or #pnode.nextl > 1 then
	 map(function (seg)
		strtab[#strtab+1] = "\n" .. string.rep(indc, ind*indmul)
		__path2str(seg.next, ind+1)
	     end, pnode.nextl)
      else
	 strtab[#strtab+1] = '->'
	 __path2str(pnode.nextl[1].next, ind)
      end
   end

   __path2str(path, 1)
   local ret = table.concat(strtab)

   if string.match(ret, '\n') then return '\n' .. ret
   else return ret end
end

-- just take first
local function conflict_resolve(fsm, pnode)
   fsm.warn("conflicting transitions from src " .. pnode.nextl[1].trans.src._fqn .. " to")
   utils.foreach(function (seg) fsm.warn("\t", seg.trans.tgt._fqn) end, pnode.nextl)
   return pnode.nextl[1]
end

----------------------------------------
-- execute a path (compound transition) starting with pnode
-- returns true if path was executed sucessfully
local function exec_path(fsm, path)
   -- heads is list parallel pnodes
   local function __exec_path(heads)
      local next_heads = {}

      -- execute outgoing transitions from path node and write next
      -- pnode to next_heads
      local function __exec_pnode_step(pn)
	 -- fsm.dbg("exec_pnode ", pn.node._fqn)
	 if is_join(pn.node) then
	    -- we are passing through the join (pn.nextl ~= false).
	    -- This is only the case if this we are exiting the
	    -- last active region of the psta.  node_find_enable must
	    -- detect this and find a full path instead if stopping at
	    -- the join. If we are passing through and thus exiting
	    -- the psta we must reset the join.
	    if pn.nextl == false then -- decrement a join
	       if not pn.node._join_cnt then
		  pn.node._join_cnt = #pn.node._itrs - 1
	       elseif pn.node._join_cnt == 1 then
 		  send_events(fsm, "e_done@" .. pn.node._parent._fqn)
		  pn.node._join_cnt = nil
	       else
		  pn.node._join_cnt = pn.node._join_cnt - 1
	       end
	       fsm.dbg("JOIN_PATH_NODE_STEP", "node._fqn", pn.node.fqn, ", new pn.node._join_cnt: " .. tostring(pn.node._join_cnt))
	    end
	    -- else
	    --    assert(pn.node._join_cnt == 1)
	    --    local seg = pn.nextl[1]
	    --    exec_trans(fsm, seg.trans)
	    --    next_heads[#next_heads+1] = seg.next
	    --    pn.node._join_cnt = nil
	    --    fsm.dbg("JOIN_PATH_NODE_STEP", "node._fqn", pn.node.fqn, " join_cnt == 0, passing through")
	    -- end

	 elseif pn.nextl == false then
	    -- if we stop on a final junction raise "done@parent"
	    -- event. Otherwise just return (we have reached a stable
	    -- conf)
	    if is_junc(pn.node) and pn.node._id == 'final' then
	       send_events(fsm, "e_done@" .. pn.node._parent._fqn)
	    end
	    return
	 elseif is_sta(pn.node) then
	    local seg = pn.nextl[1]
	    exec_trans(fsm, seg.trans)
	    next_heads[#next_heads+1] = seg.next
	 elseif is_junc(pn.node) then -- step a junction
	    local seg
	    if #pn.nextl > 1 then seg = conflict_resolve(fsm, pn)
	    else seg = pn.nextl[1] end
	    exec_trans(fsm, seg.trans)
	    next_heads[#next_heads+1] = seg.next
	 elseif is_fork(pn.node) then -- step a fork
	    exec_trans_exit(fsm, pn.nextl[1].trans) -- exit src only once
	    for _,seg in ipairs(pn.nextl) do
	       exec_trans_effect(fsm, seg.trans)
	       exec_trans_enter(fsm, seg.trans)
	       next_heads[#next_heads+1] = seg.next
	    end
	 else
	    fsm.err("ERR (exec_path)", "invalid type of head pnode: " .. pn.node._fqn)
	 end
      end

      -- execute trans. and create new next_heads table
      map(__exec_pnode_step, heads)
      if #next_heads == 0 then return true
      else return __exec_path(next_heads) end
   end

   fsm.dbg("EXEC_PATH", path2str(path))
   return __exec_path{path}
end

----------------------------------------
-- check if transition is triggered by events and guard is true
-- events is a table of entities which support '=='
--
-- tbd: allow more complex events: '+', '*', or functions
-- important: no events is "null event"
local function is_enabled(tr, events)

   local function is_member(list, e)
      for _,v in ipairs(list) do
	 if v==e then return true end
      end
      return false
   end

   local function is_triggered(tr_ev, evq)
      for _,v in ipairs(evq) do
	 if is_member(tr_ev, v) then
	    return true
	 end
      end
      return false
   end

   -- is transition enabled by current events?
   if tr.events then
      if not is_triggered(tr.events, events) then return false end
   end

   -- guard condition?
   if not tr.guard then return true end

   local ret = tr.guard(tr, events)

   return ret
end

----------------------------------------
-- returns a path starting from node which is enabled by events
-- tbd: describe exactly what a transition looks like
--
-- tbd: this function can be simplified a lot by merging the two
-- __find functions and including the __node function inside
function node_find_enabled(fsm, start, events)

   -- forward declarations
   local __find_conj_path, __find_disj_path

   -- internal dispatcher
   local function __node_find_enabled(start, events)

      assert(is_node(start), "node type expected")

      if is_junc(start) then
	 if start._id == 'final' then
	    return { node=start, nextl=false }
	 end
	 return __find_disj_path(start, events)
      elseif is_fork(start) then return __find_conj_path(start, events)
      elseif is_join(start) then return { node=start, nextl=false }
      elseif is_sta(start) then return { node=start, nextl=false }
      else fsm.err("ERROR: node_find_path invalid starting node"
		     .. start._fqn .. ", type" .. start:type()) end
   end

   -- find conjunct path (src is fork), only valid of _all_ outgoing
   -- transitions return valid paths
   function __find_conj_path(fork, events)
      local cur = { node=fork, nextl={} }
      local tail

      -- tbd: consider: how bad is this? Does is mean deadlock? This
      -- is checked statically and is not necessary here any
      if fork._otrs == nil then
	 fsm.warn("no outgoing transitions from " .. fork._fqn)
	 return false
      end

      for k,tr in pairs(fork._otrs) do
	 if not is_enabled(tr, events) then
	    fsm.err("failing to enter fork")
	    return false
	 end
	 tail = __node_find_enabled(tr.tgt, events)
	 -- if *any* path fails we return false
	 if not tail then return false
	 else table.insert(cur.nextl, { trans=tr, next=tail }) end
      end
      return cur
   end

   -- find disjunct path, returns at least one valid path
   function __find_disj_path(nde, events)
      local cur = { node=nde, nextl={} }
      local tail

      -- path ends if no outgoing path. This will be warned about statically
      if nde._otrs == nil then
	 --fsm.warn("no outgoing transitions from " .. nde._fqn)
	 return false
      end

      for k,tr in pairs(nde._otrs) do
	 if is_enabled(tr, events) then
	    tail = __node_find_enabled(tr.tgt, events)
	    if tail then table.insert(cur.nextl, {trans=tr, next=tail}) end
	 end
      end

      if #cur.nextl == 0 then
	 return false
      end
      return cur
   end

   assert(is_node(start), "node type expected")

   if is_fork(start) then return __find_conj_path(start, events)
   else return __find_disj_path(start, events) end

   -- if is_junc(start) then return __find_disj_path(start, events)
   -- elseif is_fork(start) then return __find_conj_path(start, events)
   -- elseif is_sta(start) or is_join(start) then return { node=start, nextl=false }
   -- else fsm.err("ERROR: node_find_path invalid starting node"
   -- 		  .. start._fqn .. ", type" .. start:type()) end
end

----------------------------------------
-- walk down the active tree and call find_path for all active states.
-- Take care of correct handling of parallel states.
--
-- todo: one issue: we just return the first path found altough there
-- could be more with equal priority (emanating from a parallel
-- sibling at the same depth)
local function fsm_find_enabled(fsm, events)
   local depth = 0

   -- states is table of active states at a certain depth
   local function __find_enabled(states)
      local next={}

      for i,s in ipairs(states) do
	 fsm.dbg("CHECKING", "depth:", depth, "for transitions from " .. s._fqn)
	 path = node_find_enabled(fsm, s, events)
	 if path then return path end
	 for ac,_ in pairs(actchild_get(s)) do
	    next[#next+1] = ac
	 end
      end
      depth = depth + 1
      if #next == 0 then return
      else return __find_enabled(next) end
   end

   return __find_enabled{ fsm }
end


----------------------------------------
-- attempt to transition the fsm
local function transition(fsm, events)
   fsm.dbg("TRANSITION", "searching transitions for events", events)

   local path = fsm_find_enabled(fsm, events)
   if not path then
      fsm.dbg("TRANSITION", "no enabled paths found")
      return false
   else return exec_path(fsm, path) end
end

----------------------------------------
-- enter fsm for the first time
local function enter_fsm(fsm, events)
   fsm._mode = 'active'
   local path = node_find_enabled(fsm, fsm.initial, events)

   if path == false then
      fsm._mode = 'inactive'
      return false
   end

   exec_path(fsm, path)
   return true
end

----------------------------------------
-- 0. any events? If not then run doo's of active states
-- 1. find valid transitions
--    1.1. get list of events
--	 1.2 apply them top-down to active configuration
-- 2. execute the transition
--    2.1 find transition trajectory
--    2.2 execute it
function step(fsm)
   local idling = true

   local events = getallev(fsm)

   -- entering fsm for the first time
   --
   -- it is impossible to exit it again, as there exist no transition
   -- targets outside of the FSM
   if fsm._mode ~= 'active' then
      if not enter_fsm(fsm, events) then
	 fsm.err("ERROR: failed to enter fsm root " .. fsm._id .. ", no valid path from root.initial")
	 return false
      end
      idling = false
   elseif #events > 0 then
      -- received events, attempt to transition
      transition(fsm, events)
      idling = false
   else
      -- no events, run do functions
      if run_doos(fsm) then idling = false end
   end

   if fsm.drop_events then fsm.drop_events(events) end

   -- low level control hook
   if fsm._ctl_hook then fsm._ctl_hook(fsm) end

   -- nothing to do - run an idle function or exit
   if idling then
      if fsm._idle then fsm._idle(fsm)
      else
	 fsm.dbg("HIBERNATING", "no doos, no events, no idle func, halting engines")
	 return
      end
   end

   -- tail call
   return step(fsm)
end
