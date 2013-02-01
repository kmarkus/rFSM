--
-- This file is part of rFSM.
--
-- (C) 2010,2011 Markus Klotzbuecher, markus.klotzbuecher@mech.kuleuven.be,
-- Department of Mechanical Engineering, Katholieke Universiteit
-- Leuven, Belgium.
--
-- You may redistribute this software and/or modify it under either
-- the terms of the GNU Lesser General Public License version 2.1
-- (LGPLv2.1 <http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>)
-- or (at your discretion) of the Modified BSD License: Redistribution
-- and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
--    1. Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--    2. Redistributions in binary form must reproduce the above
--       copyright notice, this list of conditions and the following
--       disclaimer in the documentation and/or other materials provided
--       with the distribution.
--    3. The name of the author may not be used to endorse or promote
--       products derived from this software without specific prior
--       written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
-- OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
-- GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
-- WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--

require ('utils')

local table = table
local io = io
local math = math
local coroutine = coroutine
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local print = print
local tostring = tostring
local string = string
local type = type
local loadstring = loadstring
local dofile = dofile
local assert = assert
local setmetatable = setmetatable
local getmetatable = getmetatable
local unpack = unpack
local error = error
local utils = utils

module("rfsm")

local map = utils.map
local foreach = utils.foreach

preproc = {}

--------------------------------------------------------------------------------
-- Model Elements and generic helper functions
--------------------------------------------------------------------------------

-- State
-- required: -
-- optional: entry, doo (only if leaf) exit, states, connectors, transitions
-- 'root' is a composite state which requires an 'initial' connector
state = {}
state.rfsm=true

function state:type() return 'state' end
function state:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end
setmetatable(state, {__call=state.new})


--
-- transition
--

local function events2str(ev)
   if not ev then return "{}"
   elseif type(ev) == 'table' then
      return table.concat(map(tostring, ev), ", ")
   else
      return tostring(ev)
   end
end

trans = {}
trans.rfsm=true

function trans:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end
setmetatable(trans, {__call=trans.new})

function trans:type() return 'transition' end

function trans:__tostring()
   local src, tgt = "none", "none"
   local pn = ""

   if self.src then
      if type(self.src) == 'string' then
	 src = self.src
      else src = self.src._fqn end
   end

   if self.tgt then
      if type(self.tgt) == 'string' then tgt = self.tgt
      else tgt = self.tgt._fqn end
   end

   if self.pn then pn = ', pn=' .. tostring(self.pn) end

   return "T={ src='" .. tostring(src) .. "', tgt='" .. tostring(tgt) .. pn .. "', events='" .. events2str(self.events) .. "' }" end

--
-- connector
--
conn = {}
conn.rfsm=true

function conn:type() return 'connector' end
function conn:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end
setmetatable(conn, {__call=conn.new})

-- aliases
sista = state; simple_state = state
csta = state; composite_state = state
connector = conn
transition = trans
yield = coroutine.yield

-- check if a table key is metadata (for now starts with a '_')
function is_meta(key) return string.sub(key, 1, 1) == '_' end

-- usefull predicates
function is_fsmobj(s)
   local mt = getmetatable(s)
   if mt and mt.rfsm then return true
   else return false end
end

-- type predicates
-- @param state
-- @return true if yes, false otherwise
function is_state(s) return is_fsmobj(s) and s:type() == 'state' end
function is_trans(s) return is_fsmobj(s) and s:type() == 'transition' end
function is_conn(s)  return is_fsmobj(s) and s:type() == 'connector' end
function is_node(s)  return is_state(s) or is_conn(s) end

--- check if a state has subnodes
local function has_subnodes(s)
   for name,val in pairs(s) do
      if not is_meta(name) and is_node(val) then return true end
   end
   return false
end

-- derived properties: is_composite/is_leaf
function is_composite_slow(s) return is_state(s) and has_subnodes(s) end
function is_leaf_slow(s) return is_state(s) and not is_composite(s) end
is_composite=utils.memoize(is_composite_slow)
is_leaf=utils.memoize(is_leaf_slow)

-- check for valid and initalized 'root'
function is_root(s) return is_composite(s) and s._id == 'root' end
function is_initialized_root(s) return is_composite(s) and s._id == 'root' and s._initialized end

-- a not but not root
function is_nr_node(s) return is_node(s) and not is_root(s) end

-- type->char, e.g. 'Composite'-> 'C'
function fsmobj_tochar(obj)
   if is_composite(obj) then return "CS"
   elseif is_leaf(obj) then return "LS"
   elseif is_trans(obj) then return "TR"
   elseif is_conn(obj) then return "c"
   else return end
end

-- check if src is connected to tgt by a transition
local function is_connected(src, tgt)
   assert(src._otrs, "ERR, is_connected: no ._otrs table found")
   for _,t in pairs(src._otrs) do
      if t.tgt._fqn == tgt._fqn then return true end
   end
   return false
end


--- Load fsm from file.
-- The file must contain an rfsm simple or composite state that is returned.
-- @param file name of file
-- @return uninitalized fsm.
function load(file)
   local fsm = dofile(file)
   if not is_state(fsm) then
      error("rfsm.load: no valid rfsm in file '" .. tostring(file) .. "' found.")
   end
   return fsm
end

--- Add a post step hook.
-- This function will add a hook to be called each time the fsm is
-- advanced.
-- @param fsm fsm root to which the hook should be added
-- @param hook hook function to be called
-- @param where where to insert the new hook 'before' or 'after' the existing ones.
function post_step_hook_add(fsm, hook, where)
   where = where or 'after'
   fsm.post_step_hook=utils.advise(where, fsm.post_step_hook, hook)
end

--- Add a post step hook.
-- This function will add a hook to be called each time the fsm is
-- advanced.
-- @param fsm fsm root to which the hook should be added
-- @param hook hook function to be called
-- @param where where to insert the new hook 'before' or 'after' the existing ones.
function pre_step_hook_add(fsm, hook, where)
   where = where or 'after'
   fsm.pre_step_hook=utils.advise(where, fsm.pre_step_hook, hook)
end


--- Apply func to all fsm elements for which pred is true
-- func accepts three arguments: the model element, its fsm parent and
-- its name.
-- @param func function to apply to fsm elements
-- @param fsm root of fsm to start with
-- @param pred predicate function
-- @depth depth maximum depth to enter (default: no limit)
-- @return flat table with results of function application
function mapfsm(func, fsm, pred, depth)
   local res = {}
   local depth = depth or -1
   local function __mapfsm(states, depth)
      if depth == 0 then return end
      map(function (s, k)
	     -- ugly: ignore entries starting with '_'
	     if not is_meta(k) then
		if pred(s) then
		   res[#res+1] = func(s, states, k)
		end
		if is_composite(s) then
		   __mapfsm(s, depth-1)
		end
	     end
	  end, states)
   end
   if is_root(fsm) then
      if pred(fsm) then res[#res+1] = func(fsm, fsm, "root") end
   end
   __mapfsm(fsm, depth)
   return res
end

-- execute func on all vertical states between from and to
-- from must be a child of to (for now)
function map_from_to(fsm, func, from, to)
   local walker = from
   local res = {}
   while true do
      res[#res+1] = func(fsm, walker)
      if walker == to then break end
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
   if not is_state(parent) then
      mes[#mes+1] = "parent " .. parent._fqn .. " of " .. id .. " not a state"
   end

   if parent.doo then
      mes[#mes+1] = "parent " .. parent._fqn .. " defines a doo function!"
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
   if is_leaf(obj) or is_conn(obj) then
      parent[id] = obj
      obj._parent = parent
      obj._id = id
      obj._fqn = parent._fqn ..'.' .. id
      -- tbd: update otrs?
   elseif is_trans(obj) then
      parent[#parent+1] = obj
      obj.src._otrs[#obj.src._otrs+1] = obj
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
      elseif s._id == 'root' and s._parent == s then
	 s._fqn='root'
      else
	 s._fqn = p._fqn .. "." .. s._id
      end
   end

   mapfsm(__add_fqn, fsm, is_node)
end

----------------------------------------
-- be nice: add default connectors so that the user doesn't not have
-- to do this boring job
local function add_defconn(fsm)

   -- if transition *locally* references a non-existant initial or
   -- final connector create it
   local function __add_trans_defconn(tr, p)
      if is_composite(p) then
	 if tr.src == 'initial' and p.initial == nil then
	    fsm_merge(fsm, p, conn:new{}, 'initial')
	    fsm.info("INFO: created undeclared connector " .. p._fqn .. ".initial")
	 end
      end
   end

   mapfsm(__add_trans_defconn, fsm, is_trans)
end

--- Set event table t[event]=true of each event.
-- @param fsm initialized root fsm.
local function index_events(fsm)
   mapfsm(function (tr, p)
	     if tr.events then
		tr._idx_events={}
		for i,e in ipairs(tr.events) do
		   tr._idx_events[e]=true
		end
	     end
	  end, fsm, is_trans)
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
-- expand e_done events into e_done@fqn
local function expand_e_done(fsm)
   mapfsm(function (tr, p)
	     if not tr.events then return end
	     for i=1,#tr.events do
		if tr.events[i] == 'e_done' then
		   tr.events[i] = 'e_done' .. '@' .. tr.src._fqn
		end
	     end
	  end, fsm, is_trans)
end

----------------------------------------
-- sort otrs according to priority numbers
-- must be called after add_otrs obviously
local function sort_otrs_pn(fsm)
   -- sort greater first, no pn amounts to pn=0
   local function tr_gt (t1, t2)
      local pn1 = t1.pn or 0
      local pn2 = t2.pn or 0
      return pn1 > pn2
   end

   mapfsm(function (nd)
	     table.sort(nd._otrs, tr_gt)
	  end, fsm, is_node)
end

----------------------------------------
-- resolve path function
-- turn string state into the real thing
function __resolve_path(fsm, state_str, parent)

   -- index tree with array tab
   local function index_tree(tree, tab)
      if tab[1] == 'root' or tab[1] == fsm._id then
	 return index_tree(tree, utils.cdr(tab))
      end
      local res = tree
      for _, k in ipairs(tab) do
	 res = res[k]
	 if not res then
	    mes = "no " .. k .. " in " .. table.concat(tab, ".", 1, #tab-1)
	    break
	 end
      end
      return res, mes
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
      state, mes = index_tree(parent, utils.split(state_str, "[\\.]"))
   else
      -- absolute target, this is a fqn!
      state, mes = index_tree(fsm, utils.split(state_str, "[\\.]"))
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
	 fsm.warn("ERROR: internal events not supported (yet?)")
	 return false
      end

      local tgt, mes = __resolve_path(fsm, tr.tgt, parent)

      if not tgt then
	 fsm.err("ERROR: resolving tgt failed " .. tostring(tr) .. ": " .. mes )
	 return false
      else
	 -- complex state, connect to 'initial'
	 if is_composite(tgt) then
	    if tgt.initial == nil then
	       fsm.err("ERROR: transition " .. tostring(tr) .. " ends on composite state without initial connector")
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

   local function check_composite(s, p)
      local ret = true
      if s.initial and not is_conn(s.initial) then
	 fsm.err("ERROR: in composite " .. p._fqn .. ".initial is not of type connector but " .. s.initial:type())
	 ret = false
      end

      if s.doo then
	 fsm.err("ERROR: doo not permitted in composite states: " .. p._fqn .. "." .. s._id)
	 ret = false
      end

      return ret
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

      if t.events and type(t.events) ~= 'table' then
	 mes[#mes+1] = "ERROR: " .. tostring(t) .." 'events' field must be a table"
	 ret = false
      end

      if t.event then
	 mes[#mes+1] = "WARNING: " .. tostring(t) .." 'event' field has no meaning, did you mean 'events'?"
      end

      -- tbd event
      return ret
   end

   -- root
   if not is_state(fsm)  then
      mes[#mes+1] = "ERROR: fsm not a composite state but of type " .. fsm:type()
      res = false
   end

   if fsm.initial == nil then
      mes[#mes+1] = "ERROR: fsm " .. fsm._id .. " without initial connector"
      res = false
   end

   -- no side effects, order does not matter
   res = res and utils.andt(mapfsm(check_node, fsm, is_node))
   res = res and utils.andt(mapfsm(check_composite, fsm, is_composite))
   res = res and utils.andt(mapfsm(check_trans, fsm, is_trans))

   return res, mes
end

function check_no_otrs(fsm)
   local function __check_no_otrs(s, p)
      if s._otrs == nil or #s._otrs == 0 then
	 fsm.warn("WARNING: no outgoing transitions from node '" .. s._fqn .. "'")
	 return false
      else return true end
   end
   return utils.andt(mapfsm(__check_no_otrs, fsm, is_nr_node))
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
   foreach(setup_printer, { err=utils.stderr, warn=utils.stderr,
			    info=utils.stdout, dbg=__null_func } )
end

--- initialize fsm from rfsm template
-- @param rfsm template to initialize
-- @return inialized fsm
function init(fsm_templ)

   assert(is_state(fsm_templ), "invalid fsm model passed to rfsm.init")

   local fsm = utils.deepcopy(fsm_templ)

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

   add_otrs(fsm) -- add outgoing transition table
   check_no_otrs(fsm)
   expand_e_done(fsm)
   sort_otrs_pn(fsm)

   fsm._act_leaf = false

   fsm._intq = { 'e_init_fsm' }
   fsm._curq = {}

   -- getevents user hook supplied?
   -- must return a table with events
   if not fsm.getevents then
      fsm.getevents = function () return {} end
   end

   -- run user preproc hooks
   for k,f in ipairs(preproc) do f(fsm) end

   -- This has to take place so late because some preproc hooks might
   -- transform events (e.g. timeevent)
   index_events(fsm)

   -- All OK!
   fsm._initialized = true
   return fsm
end

--- Reset a fsm.
-- This clears all events, and makes it inactive so the next step or
-- run will enter via root initial again.
-- @param fsm root fsm.
function reset(fsm)
   assert(fsm._initialized, "Can't reset an uninitalized fsm")
   fsm._intq = { 'e_init_fsm' }
   fsm._curq = {}
   fsm._act_leaf = false
   mapfsm(function (c) c._actchild = nil end, fsm, is_composite)
   mapfsm(function (s) s._doo_co = nil end, fsm, is_leaf)
end


--------------------------------------------------------------------------------
-- Operational Functions
--------------------------------------------------------------------------------

----------------------------------------
-- send events to the local fsm event queue
function send_events(fsm, ...)
   if not fsm or not is_initialized_root(fsm) then error("ERROR send_events: invalid fsm argument") end
   fsm.dbg("RAISED", ...)
   for _,v in ipairs({...}) do table.insert(fsm._intq, v) end
end

-- 1. walk up source path until root
-- 2. walk up target path until a state is found which is part of the
--    source path. This state is the LCA.
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

----------------------------------------
-- check for new external events and merge them into the internal
-- queue. return the number of events in the queue.
function check_events(fsm)
   local extq = fsm.getevents()
   local intq = fsm._intq
   for _,v in ipairs(extq) do table.insert(intq, v) end
   return #intq
end

local function get_events(fsm)
   check_events(fsm)
   local ret = fsm._intq
   fsm._intq = {}
   return ret
end

----------------------------------------
-- actchild handling
local function actchild_add(parent, child)
   if parent._actchild ~= nil then
      error("actchild_add: error adding " .. child._fqn .. ", parent " .. parent._fqn .. " already has an active child " .. parent._actchild._fqn)
   end
   parent._actchild = child
end

local function actchild_rm(parent, child)
   parent._actchild = nil
end

-- return actchild, can be nil!
function actchild_get(state) return state._actchild end

-- get state mode
function get_sta_mode(s)
   return s._mode or "inactive"
end

-- set state mode
function set_sta_mode(s, m)
   assert(is_state(s), "can't set_mode on non state type")

   if is_leaf(s) then assert(m=='active' or m=='inactive' or m=='done')
   else assert(m=='active' or m=='inactive') end -- must be a csta

   s._mode = m
   if m=='inactive' then actchild_rm(s._parent, s)
   elseif m=='active' then actchild_add(s._parent, s)
   else -- in 'done' it should be active already
      assert(s._parent._actchild == s, "set_sta_mode: ERROR: 'done' but not actchild of parent")
   end
   return s._mode
end

----------------------------------------
-- run one doo functions of an active state and place it at the end of
-- the active queue
-- active_leaf states might not have a doo function, so check
-- returns true if there is at least one active doo, otherwise false
local function run_doos(fsm)
   local doo_done = false
   local doo_idle = false  -- fsm.doo_idle_def -- default for doo_idle???

   -- can safely assume an act_leaf exists, because run_doos is never
   -- called during transitions.
   if get_sta_mode(fsm._act_leaf) ~= 'active' then
      return true
   else
      local state = fsm._act_leaf

      -- create new coroutine
      if state.doo and not state._doo_co then
	 fsm.dbg("DOO", "created coroutine for " .. state._fqn .. " doo")
	 state._doo_co = coroutine.create(state.doo)
      end

      -- corountine still active, can be resumed
      if state._doo_co and  coroutine.status(state._doo_co) == 'suspended' then
	 local cr_stat, cr_ret = coroutine.resume(state._doo_co, fsm, state, 'doo')
	 if not cr_stat then
	    fsm.err("DOO", "doo program of state '" .. state._fqn .. "' failed: ", cr_ret)
	    doo_done = true
	    state._doo_co = nil
	    set_sta_mode(state, 'done')
	    -- tbd: raise event
	 else
	    doo_idle = cr_ret or doo_idle -- this allows to provide a default, see above.
	    if coroutine.status(state._doo_co) == 'dead' then
	       doo_done = true
	       state._doo_co = nil
	       set_sta_mode(state, 'done')
	       send_events(fsm, "e_done@" .. state._fqn)
	       fsm.dbg("DOO", "removing completed coroutine of " .. state._fqn .. " doo")
	    end
	 end
      end
   end
   return doo_done, doo_idle
end

--- enter a state (and nothing else)
-- @param fsm initialized rfsm state machine
-- @param state the state to enter
-- @param hot hot entry: resume an previous coroutine if available
local function enter_one_state(fsm, state, hot)

   if not is_state(state) then return end
   set_sta_mode(state, 'active')
   if state.entry then
      local succ, err = pcall(state.entry, fsm, state, 'entry')
      if not succ then
	 fsm.err('ENTRY', "error executing entry of " ..  state._fqn .. ": ", err)
	 -- tbd: raise event
      end
   end

   if is_leaf(state) then
      fsm._act_leaf = state
      if not state.doo then
	 set_sta_mode(state, 'done')
	 send_events(fsm, "e_done@" .. state._fqn)
      else -- is there an old coroutine lingering?
	 if not hot and state._doo_co then state._doo_co = nil end
      end
   end
   fsm.dbg("STATE_ENTER", state._fqn)
end



--- Exit a state including its substates
-- @param fsm root fsm
-- @param state state to exit
function exit_state(fsm, state)

   if not is_state(state) then return end  -- don't try to exit connectors.

   -- if composite exit child states first
   if is_composite(state) then exit_state(fsm, actchild_get(state)) end

   if is_state(state) then
      -- save this for possible history entry
      state._parent._last_active = state
      state._parent._last_active_mode = get_sta_mode(state)

      set_sta_mode(state, 'inactive')

      if state.exit then
	 local succ, err = pcall(state.exit, fsm, state, 'exit')
	 if not succ then
	    fsm.err('EXIT', "error executing exit of " ..  state._fqn .. ": ", err)
	    -- tbd: raise event
	 end
      end

      -- don't cleanup coroutine, could be used later
      if is_leaf(state) then fsm._act_leaf = false end
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
      -- tbd: raise event
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
   --   - transitions between connectors of same scope

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
      local succ, err = pcall(tr.effect, fsm, tr, 'effect', events)
      if not succ then
	 fsm.err('EFFECT', "error executing effect of " ..  tostring(tr) .. ": ", err)
	 -- tbd: raise event
      end
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

      if  #pnode.nextl > 1 then
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
   foreach(function (seg) fsm.warn("\t", seg.trans.tgt._fqn) end, pnode.nextl)
   return pnode.nextl[1]
end

----------------------------------------
-- execute a path (compound transition) starting with pnode
-- returns true if path was executed sucessfully
local function exec_path(fsm, path)

   -- heads is list of path nodes
   local function __exec_path(head)
      local next_head

      -- execute outgoing transitions from path node and write next
      -- pnode to next_head
      local function __exec_pnode_step(pn)
	 -- fsm.dbg("exec_pnode ", pn.node._fqn)
	 local seg
	 if pn.nextl == false then
	    -- We have reached a stable configuration!
	    return
	 elseif is_state(pn.node) then
	    -- todo: why not check for conflicts here? because they
	    -- are currently not possible...
	    seg = pn.nextl[1]
	    exec_trans(fsm, seg.trans)
	    next_head = seg.next
	 elseif is_conn(pn.node) then -- step a connector
	    if #pn.nextl > 1 then seg = conflict_resolve(fsm, pn)
	    else seg = pn.nextl[1] end
	    exec_trans(fsm, seg.trans)
	    next_head = seg.next
	 else
	    fsm.err("ERR (exec_path)", "invalid type of head pnode: " .. pn.node._fqn)
	 end
      end

      __exec_pnode_step(head)
      if next_head == nil then return true end
      return __exec_path(next_head)
   end

   fsm.dbg("EXEC_PATH", path2str(path))
   return __exec_path(path)
end

----------------------------------------
-- check if transition is triggered by events and guard is true
-- events is a table of entities which support '=='
--
-- tbd: allow more complex events: '+', '*', or functions
-- important: no events is "null event"
local function is_enabled(fsm, tr, events)

   local function is_triggered(tr, evq)
      local idx_ev = tr._idx_events -- indexed events
      for _,e in ipairs(evq) do
	 if idx_ev[e] then return true end
      end
      return false
   end

   -- guard condition?
   if tr.guard then
      local succ, ret = pcall(tr.guard, tr, events)
      if succ == false then
	 fsm.err('GUARD', "error executing guard of " ..  tostring(tr) .. ": ", ret)
	 -- tdb: raise event
	 return false
      end
      if ret == false then return false end
   end

   -- Is transition enabled by current events?
   if tr.events and #tr.events > 0 then
      return is_triggered(tr, events)
   end

   return true
end

----------------------------------------
-- returns a path starting from node which is enabled by events
-- tbd: describe exactly what a transition looks like
--
-- tbd: this function can be simplified a lot by merging the two
-- __find functions and including the __node function inside
--
-- a path always starts from a node_descriptor which is defined by a
-- table { node=stateX, nextl=...}. The nextl field is a table of
-- tables which specify transition segments: { trans=transZ next=next_node_desc }

function node_find_enabled(fsm, start, events)

   -- find a path starting from node
   function __find_path(nde, events)
      local cur = { node=nde, nextl={} }

      -- path ends if no outgoing path. The static validation should
      -- have raised a warning earlier.
      if nde._otrs == nil then return false end

      -- check all outgoing transitions from nde
      for k,tr in pairs(nde._otrs) do
	 if is_enabled(fsm, tr, events) then
	    -- find continuation
	    local tgt = tr.tgt
	    local tail
	    if is_leaf(tgt) then tail = { node=tgt, nextl=false }
	    elseif is_conn(tgt) then tail = __find_path(tgt, events)
	    else fsm.err("ERROR: node_find_path invalid starting node"
			 .. start._fqn .. ", type" .. start:type()) end
 	    if tail then cur.nextl[#cur.nextl+1] = {trans=tr, next=tail} end
	 end
      end

      -- no paths found
      if #cur.nextl == 0 then return false end
      return cur
   end

   assert(is_node(start), "node type expected")
   return __find_path(start, events)
end

----------------------------------------
-- walk down the active tree and call find_path for all active states.
local function fsm_find_enabled(fsm, events)
   local depth = 0

   -- states is table of active states at a certain depth
   local function __find_enabled(state)
      fsm.dbg("CHECKING", "depth:", depth, "for transitions from " .. state._fqn)
      path = node_find_enabled(fsm, state, events)
      if path then return path end
      local next = actchild_get(state)
      if not next then return end
      depth = depth + 1
      return __find_enabled(next)
   end

   return __find_enabled(fsm)
end


----------------------------------------
-- attempt to transition the fsm
local function transition(fsm, events)
   fsm.dbg("TRANSITION", "searching transitions for events: " .. events2str(events))

   local path = fsm_find_enabled(fsm, events)
   if not path then
      fsm.dbg("TRANSITION", "no enabled paths found")
      return false
   end
   exec_path(fsm, path)
   return true
end

----------------------------------------
-- enter fsm for the first time
local function enter_fsm(fsm, events)
   local path = node_find_enabled(fsm, fsm.initial, events)

   if path == false then
      fsm._mode = 'inactive'
      return false
   end

   enter_one_state(fsm, fsm)
   fsm._actchild = nil -- unset because the previous line set this to fsm
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
--
-- conditions to return from this function:
-- 	- n==0
--	  if n > 0 and
--           - doo_completed and #events == 0 or
--	     - doo_idle and #events == 0
--

--- step the fsm n-times.
-- Step the given initialized fsm for n times. A step can either be a
-- transition or a run of the doo program.
-- @param fsm initialized rfsm state machine
-- @param n number of steps to execute. default: 1.
-- @return idle boolean if fsm is idle or not
function step(fsm, n)
   if not is_initialized_root(fsm) then fsm.err("ERROR step: invalid fsm") end

   local idle = true
   local n = n or 1
   local do_dec = true		-- if false n will not be decremented
   local curq = get_events(fsm) -- return table with all current events

   -- low level pre-step hook
   if fsm.pre_step_hook then fsm.pre_step_hook(fsm, curq) end

   -- entering fsm for the first time: it is impossible to exit it
   -- again, as there exist no transition targets outside of the
   -- FSM. What about root self transition?
   if fsm._mode ~= 'active' then
      if not enter_fsm(fsm, curq) then
	 fsm.err("ERROR: failed to enter fsm root " .. fsm._id .. ", no valid path from root.initial")
	 return false
      end
      idle = false
   elseif #curq > 0 then	-- received events, attempt to transition
      do_dec = transition(fsm, curq)
      idle = false
   else
      -- no events, run doo
      local doo_done, doo_idle = run_doos(fsm)
      if doo_done or doo_idle then
	 -- if doo is idle we still check for events (which might have
	 -- been generated by the doo itself) and if available try to
	 -- transition:
	 if check_events(fsm) > 0 then idle = false else idle = true end
      else idle = false end -- doo not idle
   end

   if fsm.post_step_hook then fsm.post_step_hook(fsm, curq) end

   -- do not dec if no transition executed.
   if do_dec then n = n - 1 end

   if n < 1 then
      return idle
   else
      if idle then
	 if fsm.idle_hook then fsm.idle_hook(fsm); idle = false  -- call idle hook
	 else
	    fsm.dbg("HIBERNATING", "no events, no idle_hook, no doos or doo idle, halting engines")
	    return true -- we are idle
	 end
      end
   end
   -- tail call
   return step(fsm, n)
end

--- run the fsm until there is nothing else to do.
-- Run the given initialized fsm until there are no events to process,
-- the doo function has completed or is idle.
-- @param fsm initialized rfsm state machine
-- @return idle boolean if fsm is idle or not
function run(fsm)
   if not is_initialized_root(fsm) then fsm.err("ERROR", "run: invalid fsm") end
   return step(fsm, math.huge)
end
