--------------------------------------------------------------------------------
--  Lua based robotics finite state machine engine
--------------------------------------------------------------------------------

require ('utils')

param = {}
param.err = print
param.warn = print
param.info = print
param.dbg = print

-- save references

local param, pairs, ipairs, print, tostring, table, string, type,
loadstring, assert, coroutine, setmetatable, getmetatable, utils =
param, pairs, ipairs, print, tostring, table, string, type,
loadstring, assert, coroutine, setmetatable, getmetatable, utils

module("rtfsm")

local map = utils.map

--------------------------------------------------------------------------------
-- Model Elements

--
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
   local src, tgt, event

   if type(self.src) == 'string' then src = self.src
   else src = self.src._fqn end

   if type(self.tgt) == 'string' then tgt = self.tgt
   else tgt = self.tgt._fqn end

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
      param.err("ERROR: no fsmobj: " .. utils.tab2str(s) .. " (interesting!)")
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
function is_conn(s)  return is_junc(s) or is_fork(s) or is_join(s) end
function is_node(s)  return is_sta(s) or is_conn(s) end
function is_pconn(s) return is_fork(s) or is_join(s) end

-- apply func to all fsm elements for which pred returns true
function mapfsm(func, fsm, pred)
   local res = {}

   local function __mapfsm(states)
      map(function (s, k)
	     -- ugly: ignore entries starting with '_'
	     if string.sub(k, 1, 1) ~= '_' then
		if pred(s) then
		   res[#res+1] = func(s, states, k)
		end
		if is_cplx(s) then
		   __mapfsm(s)
		end
	     end
	  end, states)
   end
   __mapfsm(fsm)
   return res
end


--------------------------------------------------------------------------------
-- helper function for dynamically modifying fsm
-- add obj with id under parent
function fsm_merge(parent, id, obj)
   local mes = nil
   if not is_cplx(parent) then
      mes = "parent " .. parent._fqn .. " of " .. id .. " not a complex state"
   end
   if parent[id] ~= nil then
      mes = "parent " .. parent._fqn .. " already contains a sub element " .. id
   end

   if mes then
      param.err("ERROR: merge failed: ", mes)
      return false
   end

   -- simple types
   if is_sista(obj) or is_conn(obj) then
      parent[id] = obj
      obj._parent = parent
      obj._id = id
      obj._fqn = parent._fqn ..'.' .. id
   else
      param.err("ERROR: merging of " .. obj:type() .. " objects not implemented (" .. id .. ")")
   end
   return true
end

--------------------------------------------------------------------------------
-- construct parent links
-- this modifies fsm

local function add_parent_links(fsm)
   fsm._parent = fsm
   mapfsm(function (s, p) s._parent = p end, fsm, is_node)
end

--------------------------------------------------------------------------------
-- add id fields
local function add_ids(fsm)
   mapfsm(function (s,p,n) s._id = n end, fsm, is_node)
end


--------------------------------------------------------------------------------
-- add fully qualified names (fqn) to node types
-- depends on parent links beeing available
local function add_fqns(fsm)
   function __add_fqn(s, p)
      if not s._id then
	 param.err("ERROR: state (" .. s:type() .. ") without id, parent: " .. p._fqn)
      end
      s._fqn = p._fqn .. "." .. s._id
   end

   fsm._fqn = fsm._id
   mapfsm(__add_fqn, fsm, is_node)
end

--------------------------------------------------------------------------------
-- be nice: add default connectors so that the user doesn't not have
-- to do this boring job
local function add_defconn(fsm)

   -- if initial (fork) or final (join) doesn't exist then create them
   -- and add transitions to all initial composite states
   local function __add_psta_defconn(psta, parent, id)
      if not psta.initial then
	 assert(fsm_merge(psta, 'initial', fork:new{}))
	 param.info("INFO: created undeclared fork " .. psta._fqn .. ".initial")
	 -- add transitions
	 for k,v in pairs(psta) do
	    if is_cplx(v) then
	       psta[#psta+1] = trans:new{ src="initial", tgt=v._id }
	       param.info("\t added transition initial->" .. v._id )
	    end

	 end
      end
      if not psta.final then
	 assert(fsm_merge(psta, 'final', join:new{}))
	 param.info("INFO: created undeclared join " .. psta._fqn .. ".initial")
	 -- add transitions
	 for k,v in pairs(psta) do
	    if is_cplx(v) then
	       psta[#psta+1] = trans:new{ src=v._id, tgt='final' }
	       param.info("\t added transition " .. v._id ..  "->final" )
	    end
	 end
      end
   end

   -- if transition *locally* references a non-existant initial or
   -- final connector create it
   local function __add_trans_defconn(tr, p)
      if is_csta(p) then
	 if tr.src == 'initial' and p.initial == nil then
	    fsm_merge(p, 'initial', junc:new{})
	    param.info("INFO: created undeclared connector " .. p._fqn .. ".initial")
	 end
	 if tr.tgt == 'final' and p.final == nil then
	    fsm_merge(p, 'final', junc:new{})
	    param.info("INFO: created undeclared connector " .. p._fqn .. ".final")
	 end
      elseif is_psta(p) then
	 -- tbd: create fork and join
      end
   end

   mapfsm(__add_psta_defconn, fsm, is_psta)
   mapfsm(__add_trans_defconn, fsm, is_trans)
end


--------------------------------------------------------------------------------
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
      param.err("ERROR: invalid relative transition (leading dot): " .. state_str)
   else
      -- absolute target, this is a fqn!
      state = index_tree(fsm, utils.split(state_str, "[\\.]"), mes)
   end
   return state, mes
end

--------------------------------------------------------------------------------
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
	 param.err("ERROR: resolving src failed " .. tostring(tr) .. ": " .. mes)
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
	 param.warn("WARNING: internal events not supported (yet)")
	 return true
      end

      local tgt, mes = __resolve_path(fsm, tr.tgt, parent)

      if not tgt then
	 param.err("ERROR: resolving tgt failed " .. tostring(tr) .. ": " .. mes )
	 return false
      else
	 -- complex state, connect to 'initial'
	 if is_cplx(tgt) then
	    if tgt.initial == nil then
	       param.err("ERROR: transition " .. tostring(tr) ..
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



--------------------------------------------------------------------------------
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
	 param.err("ERROR: parent of " .. s.fqn .. " is nil")
	 ret = false
      end

      if not is_node(p) then
	 param.err("ERROR: parent of " .. s.fqn .. " is not a node but of type " .. p:type())
	 ret = false
      end

      return ret
   end

   local function check_csta(s, p)
      local ret = true
      if s.initial and not is_junc(s.initial) then
	 param.err("ERROR: in composite " .. s.initial._fqn .. " is not of type junction but " .. s.initial:type())
	 ret = false
      end
      if s.final and not is_junc(s.final) then
	 param.err("ERROR: in composite " .. s.final._fqn .. " is not of type junction but " .. s.initial:type())
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
	 ret = false
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

      -- tbd event
      return ret
   end

   -- validate parallel connectors fork and join
   local function check_pconn(s, p)
      local ret = true
      -- parent of fork/join must be a psta!
      if not is_psta(p) then
	 mes[#mes+1] = "ERROR: " .. p._fqn .. " is not a parallel state"
	 ret = false
      end
      return ret
   end

   local function check_junc(j, p)
      -- parent of junction must be a csta!
      local ret = true
      if not is_csta(p) then
	 mes[#mes+1] = "ERROR: " .. p._fqn .. " is not a composite state"
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
      mes[#mes+1] = "ERROR: fsm " .. fsm.id .. "without initial junction"
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

--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- initialize fsm
-- create parent links
-- create table for lookups
function init(fsm_templ, name)

   local fsm = utils.deepcopy(fsm_templ)

   fsm._id = name or 'root'

   add_parent_links(fsm)
   add_ids(fsm)
   add_fqns(fsm)
   add_defconn(fsm)

   -- verify (early)
   local ret, errs = verify_early(fsm)
   if not ret then param.err(table.concat(errs, '\n')) return false end

   if not resolve_trans(fsm) then
      param.err("ERROR: failed to resolve transitions of fsm " .. fsm._id)
      return false
   end

   -- verify (late)
   local ret, errs = verify_late(fsm)
   if not ret then param.err(table.concat(errs, '\n')) return false end

   -- local event queue is empty
   fsm._evq = { 'e_init_fsm' }

   -- getevents user hook supplied?
   -- must return a table with events
   if not fsm.getevents then
      fsm.getevents = function () return {} end
   end

   -- All OK!
   fsm._initalized = true
   return fsm
end



--------------------------------------------------------------------------------
--
-- Operational Functions
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- send events to the local fsm event queue
function send_events(fsm, ...)
   for _,v in ipairs(args) do
      table.insert(fsm._intq, v)
   end
end

--------------------------------------------------------------------------------
-- merge all external and internal events into list
local function getallev(fsm)
   local extq = fsm.getevents()
   local res = fsm._intq

   for _,v in ipairs(extq) do
      table.insert(res, v)
   end

   fsm._intq = {}
   return res
end


--------------------------------------------------------------------------------
-- run one doo functions of an active state and place it at the end of
-- the active queue
-- returns true if there is at least one active doo, otherwise false
--
-- huh, _actq only contains the next lower active psta, right?
local function run_doos(fsm)
   local has_run = false
   for i in 1,#fsm._actq do

      -- rotate
      local state = table.remove(fsm._actq, 1)
      table.insert(fsm._actq, state)

      if state.doo and not state.doo_co then
	 state.doo_co = coroutine.create(state.doo)
      end

      if coroutine.status == 'suspended' then
	 coroutine.resume(state.doo_co)
	 has_run = true
	 break
      end
   end
   return has_run
end


--------------------------------------------------------------------------------
-- enter a state (and nothing else)
local function enter_state(state)
   if state.entry then state.entry(state) end
   state._mode = 'active'
   state._parent.act_child = state
   -- tbd: act_leaves, parallel states
end

--------------------------------------------------------------------------------
-- exit a state (and nothing else)
local function exit_state(state)
   -- save this for possible history entry
   if state.mode == 'active' then
      state._parent.last_active = state
   else
      state._parent.last_active = false
   end
   state.mode = 'inactive'
   state._parent.act_child = false
   if state.exit then state.exit(state) end
end

-- this function exploits the fact that the LCA is the first parent of
-- tgt which is in state 'active'
-- tbd: sure this works for parallel states?
local function getLCA(tr)
   local lca = trans.tgt._parent

   -- looks dangerous, but root should always be active:
   while lca ~= 'active' do
      lca = lca._parent
   end
   return lca
end


--------------------------------------------------------------------------------
-- execute a simple transition
local function exec_trans(fsm, tr)
   -- paranoid check: sth would be very wrong if tgt is already active
   if tr.tgt._mode ~= 'inactive' then
      param.err("ERROR: transition target " .. tr.tgt._fqn .. " in invalid state '" .. tr.tgt._mode .. "'")
   end

   local lca = getLCA(trans)
   local state_walker = tr.src

   --  exit all states from src up to (but excluding) LCA
   while state_walker ~= lca do
      exit_state(state)
      state_walker = state_walker._parent
   end

   -- run effect
   tr.effect(fsm, tr)

   -- implicit enter from (but excluding) LCA to trans.tgt
   -- tbd: create walker function: foreach_[up|down](start, end, function)
   local down_path = {}
   local state_walker = trans.tgt

   while state_walker ~= lca do
      table.insert(down_path, state_walker)
      state_walker = state_walker._parent
   end

   -- now enter down_path
   while #down_path > 0 do
      state_enter(table.remove(down_path))
   end
end

--------------------------------------------------------------------------------
-- execute a compound transition
-- ct is a table of transitions
local function exec_ctrans(fsm, ct)
   utils.foreach(function (tr) exec_trans(fsm, tr) end, ct)
end

--------------------------------------------------------------------------------
-- check if transition is triggered by events and guard is true
-- events is a table of entities which support '=='
--
-- tbd: allow more complex events: '+', '*', or functions
-- important: no events is "null event"
local function is_enabled(tr, events)
   -- matching events?
   if tr.events then
      for _,k in ipairs(tr.events) do
	 for _kk in ipairs(events) do
	    if k == kk then break end end end
      return false
   end
   -- guard condition?
   if not tr.guard(tr, events) then return false
   else return true end
end

--------------------------------------------------------------------------------
-- return all enabled paths starting with 'node'
-- backtracks, exponential complexity
-- inefficient but practical: returns a table of valid paths.
-- this means copying the existing path every step
--
-- parallel: if we enter a parallel state then we must check the paths
-- into all regions!
local function find_enabled_node(node, events)
   local function __check_path(tr)
      if not is_enabled(tr, events) then
	 return nil
      end

      local newtab = utils.deepcopy(tab)
      newtab[#tab+1] = tr

      if tr.tgt.type == 'simple' then return newtab
      else return check_path(tr.tgt, events, newtab) end
   end
   local tab = {}
   return map(__check_path, node.otrs)
end

--------------------------------------------------------------------------------
-- walk down the active tree and call find_path for all active states
-- tbd: deal with orthogonal regions?
local function find_enabled_fsm(fsm, events)
   local cur = fsm
   local paths
   while cur and  cur._mode ~= 'inactive' do -- => 'done' or 'active'
      paths = find_enabled_node(cur, events)
      if #paths > 0 then break end
      cur = cur.act_child
   end
   return paths
end

--------------------------------------------------------------------------------
-- attempt to transition the fsm
local function transition(fsm, events)

   -- conflict resolution could be more sophisticated
   local function select_path(paths)
      param.warn("WARNING: conflicting paths found")
      return paths[1]
   end

   local paths = find_enabled_fsm(fsm, events)
   if #paths == 0 then
      return false
   else
      return exec_ctrans(select_path(paths))
   end
end


--------------------------------------------------------------------------------
-- enter fsm for the first time
local function enter_fsm(fsm, events)
   fsm._mode = 'active'
   local path = find_enabled_node(fsm, fsm.connectors['initial'], events)

   if #path == 0 then
      fsm._mode = 'inactive'
      return false
   end

   exec_path(path)
   return true
end



--------------------------------------------------------------------------------
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
      enter_fsm(fsm, events)
      idling = false
   elseif #events > 0 then
      -- received events, attempt to transition
      if transition(fsm, events) then
	 idling = false
      end
   else
      -- no events, run do functions
      if run_doos(fsm) then idling = false end
   end

   -- nothing to do - run an idle function or exit
   if idling then
      if fsm._idle then fsm._idle(fsm)
      else
	 param.dbg("DEBUG: no doos, no events, no idle func, halting engines")
	 return
      end
   end

   -- tail call
   return step(fsm)
end


--
-- testing/debugging
--

-- define sets of input events and expected trajectory and test
-- against actually executed trajectory
--

--
-- activate all states including leaf but without running any programs
--
dbg = {}

function dbg.activate_leaf(fsm, leaf)
end

--
-- return a table describing the active configuration
--
function dbg.get_act_conf(fsm)

   local function __walk_act_path(root)
      local res = {}
      -- 'done' or 'inactive' are always the end of the active conf
      if root._mode ~= 'active' then
	 return root._mode
      end

      if is_psta(root) then
	 res[root.id] = map(__walk_act_path, root.act_child)
      elseif is_csta(root) then
	 res[root.id] = __walk_act_path(root.act_child)
      elseif is_sista(root) then
	 return root._mode
      else
	 local mes="ERROR: active non state type found, fqn=" .. root.fqn .. ", type=" .. root:type()
	 param.err(mes)
	 return mes
      end

      return res
   end

   return __walk_act_path(fsm)
end

function dbg.pp_act_conf(fsm)
   utils.tab2str(dbg.get_act_conf(fsm))
end

function dbg.table_cmp(t1, t2)
   return false
end
