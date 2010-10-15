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

local table = table
local io = io
local math = math
local coroutine = coroutine
local pairs = pairs
local ipairs = ipairs
local print = print
local tostring = tostring
local string = string
local type = type
local loadstring = loadstring
local assert = assert
local setmetatable = setmetatable
local getmetatable = getmetatable
local unpack = unpack
local error = error
local utils = utils

module("rfsm")

local map = utils.map
local foreach = utils.foreach

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
-- transition
--
trans = {}
function trans:new(t)
   setmetatable(t, self)
   self.__index = self
   return t
end

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

--
-- connector
--
conn = {}
function conn:type() return 'connector' end
function conn:new(t)
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

-- type predicates
function is_sista(s) return is_fsmobj(s) and s:type() == 'simple' end
function is_csta(s)  return is_fsmobj(s) and s:type() == 'composite' end
function is_trans(s) return is_fsmobj(s) and s:type() == 'transition' end
function is_conn(s)  return is_fsmobj(s) and s:type() == 'connector' end

function is_sta(s)   return is_sista(s) or is_csta(s) end
function is_node(s)  return is_sta(s) or is_conn(s) end

-- check for valid and initalized 'root'
function is_root(s)
   return is_csta(s) and s._id == 'root' and s._initialized
end

-- type->char, e.g. 'Composite'-> 'C'
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
		if is_csta(s) then
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
   if not is_csta(parent) then
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

   -- if transition *locally* references a non-existant initial or
   -- final connector create it
   local function __add_trans_defconn(tr, p)
      if is_csta(p) then
	 if tr.src == 'initial' and p.initial == nil then
	    fsm_merge(fsm, p, conn:new{}, 'initial')
	    fsm.info("INFO: created undeclared connector " .. p._fqn .. ".initial")
	 end
	 if tr.tgt == 'final' and p.final == nil then
	    fsm_merge(fsm, p, conn:new{}, 'final')
	    fsm.info("INFO: created undeclared connector " .. p._fqn .. ".final")
	 end
      end
   end

   mapfsm(__add_trans_defconn, fsm, is_trans)
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
-- resolve path function
-- turn string state into the real thing
local function __resolve_path(fsm, state_str, parent)

   -- index tree with array tab
   local function index_tree(tree, tab)
      local res = tree
      for _, k in ipairs(tab) do
	 res = res[k]
	 if not res then
	    mes = "no " .. k .. " in " .. table.concat(tab, ".")
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
      fsm.err("ERROR: relative transitions (leading dot) not yet supported: " .. state_str)
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
	 fsm.warn("WARNING: internal events not supported (yet)")
	 return true
      end

      local tgt, mes = __resolve_path(fsm, tr.tgt, parent)

      if not tgt then
	 fsm.err("ERROR: resolving tgt failed " .. tostring(tr) .. ": " .. mes )
	 return false
      else
	 -- complex state, connect to 'initial'
	 if is_csta(tgt) then
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
      if s.initial and not is_conn(s.initial) then
	 fsm.err("ERROR: in composite " .. s.initial._fqn .. " is not of type connector but " .. s.initial:type())
	 ret = false
      end
      if s.final and not is_conn(s.final) then
	 fsm.err("ERROR: in composite " .. s.final._fqn .. " is not of type connector but " .. s.initial:type())
	 ret = false
      end
      if s.doo then
	 mes[#mes+1] = "WARNING: " .. s .. " 'doo' function in csta will never run"
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

   -- root
   if not is_csta(fsm)  then
      mes[#mes+1] = "ERROR: fsm not a composite state but of type " .. fsm:type()
      res = false
   end

   if fsm.initial == nil then
      mes[#mes+1] = "ERROR: fsm " .. fsm._id .. " without initial connector"
      res = false
   end

   -- no side effects, order does not matter
   res = res and utils.andt(mapfsm(check_node, fsm, is_node))
   res = res and utils.andt(mapfsm(check_csta, fsm, is_csta))
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
   foreach(setup_printer, { err=utils.stderr, warn=utils.stderr,
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

   fsm._id = 'root' -- fsm._id = name or 'root'

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
   fsm._act_leaf = false

   fsm._intq = { 'e_init_fsm' }
   fsm._curq = {}

   -- getevents user hook supplied?
   -- must return a table with events
   if not fsm.getevents then
      fsm.getevents = function () return {} end
   end

   if not fsm.drop_events then
      fsm.drop_events =
	 function (fsm, events)
	    if #events>0 then fsm.dbg("DROPPING_EVENTS", events) end end
   end

   -- All OK!
   fsm._initialized = true
   return fsm
end



--------------------------------------------------------------------------------
-- Operational Functions
--------------------------------------------------------------------------------

----------------------------------------
-- send events to the local fsm event queue
function send_events(fsm, ...)
   if not is_root(fsm) then fsm.err("ERROR", fsm._name, "send_events: invalid fsm") end
   fsm.dbg("RAISED", table.concat(arg, ", "))
   for _,v in ipairs(arg) do
      table.insert(fsm._intq, v)
   end
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
local function check_events(fsm)
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
   local doo_done = false
   local doo_idle = false  -- fsm.doo_idle_def -- default for doo_idle???

   if not fsm._act_leaf then
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
	    fsm.err("DOO", "doo program of state '" .. state._fqn .. "' failed:")
	    error(cr_ret, 0)
	 else
	    doo_idle = cr_ret or doo_idle -- this allows to provide a default, see above.
	    if coroutine.status(state._doo_co) == 'dead' then
	       doo_done = true
	       state._doo_co = nil
	       sta_mode(state, 'done')
	       fsm._act_leaf = false
	       send_events(fsm, "e_done@" .. state._fqn)
	       fsm.dbg("DOO", "removing completed coroutine of " .. state._fqn .. " doo")
	    end
	 end
      end
   end
   return doo_done, doo_idle
end

----------------------------------------
-- enter a state (and nothing else)
local function enter_one_state(fsm, state)

   if not is_sta(state) then return end

   sta_mode(state, 'active')

   if state.entry then state.entry(fsm, state, 'entry') end

   if is_sista(state) then
      if state.doo then fsm._act_leaf = state
      else
	 sta_mode(state, "done")
	 send_events(fsm, "e_done@" .. state._fqn)
      end
   end

   fsm.dbg("STATE_ENTER", state._fqn)
end

----------------------------------------
-- exit a state (incl all substates)
local function exit_state(fsm, state)

   -- if complex exit child states first
   if is_csta(state) then
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
      if is_sista(state) then fsm._act_leaf = false end
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
	 elseif is_sta(pn.node) then
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

      if is_conn(start) then return __find_disj_path(start, events)
      elseif is_sta(start) then return { node=start, nextl=false }
      else fsm.err("ERROR: node_find_path invalid starting node"
		   .. start._fqn .. ", type" .. start:type()) end
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
	    if tail then cur.nextl[#cur.nextl+1] = {trans=tr, next=tail} end
	 end
      end

      if #cur.nextl == 0 then
	 return false
      end
      return cur
   end

   assert(is_node(start), "node type expected")

   return __find_disj_path(start, events)
end

----------------------------------------
-- walk down the active tree and call find_path for all active states.
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
--
-- conditions to return from this function:
-- 	- n==0
--	  if n > 0 and
--           - doo_completed and #events == 0 or
--	     - doo_idle and #events == 0
--
function step(fsm, n)
   if not is_root(fsm) then fsm.err("ERROR", fsm._name, "step: invalid fsm") end

   local idle = true
   local n = n or 1

   local curq = get_events(fsm) -- return table with all current events

   -- entering fsm for the first time: it is impossible to exit it
   -- again, as there exist no transition targets outside of the
   -- FSM. What about root self transition?
   if fsm._mode ~= 'active' then
      if not enter_fsm(fsm, curq) then
	 fsm.err("ERROR: failed to enter fsm root " .. fsm._id .. ", no valid path from root.initial")
	 return false
      end
      if fsm.drop_events then fsm.drop_events(fsm, curq) end
      idle = false
   elseif #curq > 0 then
      -- received events, attempt to transition
      transition(fsm, curq)
      if fsm.drop_events then fsm.drop_events(fsm, curq) end
      idle = false
   else
      -- no events, run doo
      local doo_done, doo_idle = run_doos(fsm)
      if doo_done then idle = true
      elseif doo_idle then
	 -- if doo is idle we still check for events (which might have
	 -- been generated by the doo itself) and if available try to
	 -- transition:
	 if check_events(fsm) > 0 then idle = false else idle = true end
      else idle = false end -- do not idle
   end

   -- low level control hook: better ._step_hook
   if fsm._ctl_hook then fsm._ctl_hook(fsm) end

   n = n - 1
   if n < 1 then return idle
   else
      if idle then
	 if fsm._idle then fsm._idle(fsm); idle = false  -- call idle hook
	 else
	    fsm.dbg("HIBERNATING", "no doos, no events, no idle func, halting engines")
	    return true -- we are idle
	 end
      end
   end
   print("restepping")
   -- tail call
   return step(fsm, n)
end

function run(fsm)
   if not is_root(fsm) then fsm.err("ERROR", fsm._name, "run: invalid fsm") end
   return step(fsm, math.huge)
end
