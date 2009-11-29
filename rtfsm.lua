--------------------------------------------------------------------------------
--  Lua based robotics finite state machine engine
--------------------------------------------------------------------------------

require ('utils')

param = {}
param.err = print
param.warn = print
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
-- connector
--
conn = {}
function conn:type() return 'connector' end
function conn:new(t)
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
      print("no fsmobj: " .. utils.tab2str(s))
      return false
   end
end

function is_sista(s) return is_fsmobj(s) and s:type() == 'simple' end
function is_csta(s)  return is_fsmobj(s) and s:type() == 'composite' end
function is_psta(s)  return is_fsmobj(s) and s:type() == 'parallel' end
function is_trans(s) return is_fsmobj(s) and s:type() == 'transition' end
function is_conn(s)  return is_fsmobj(s) and s:type() == 'connector' end
function is_join(s)  return is_fsmobj(s) and s:type() == 'join' end
function is_fork(s)  return is_fsmobj(s) and s:type() == 'fork' end

function is_sta(s)   return is_sista(s) or is_csta(s) or is_psta(s) end
function is_cplx(s)  return is_csta(s) or is_psta(s) end
function is_node(s)  return is_sta(s) or is_conn(s) end
function is_pseu(s)  return is_conn(s) or is_fork(s) or is_join(s) end

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
-- perform checks
-- test should bark loudly about problems and return false if
-- initialization is to fail
-- depends on parent links for more useful output
function verify(fsm)

   -- validate states
   local function check_state(s, parent)
      local ret = true
      if is_csta(s) then
	 if s.doo then
	    param.warn("WARNING: " .. s .. " 'doo' function in csta will never run")
	    ret = false
	 end
      end

      return ret
   end

   -- validate transitions
   local function check_trans(t, parent)
      local ret = true
      if not t.src then
	 mes[#mes+1] = "ERROR: " .. t .." missing src state, parent='" .. p._fqn .. "'"
	 ret = false
      end
      if not t.tgt then
	 mes[#mes+1] = "ERROR: " .. t .." missing tgt state, parent='" .. p._fqn .. "'"
	 ret = false
      end
      -- tbd event
      return ret
   end

   -- run checks
   local mes = {}
   local res = true

   if not is_csta(fsm)  then
      mes[#mes+1] = "ERROR: fsm not a composite state but of type " .. fsm:type()
      res = false
   end

   res = res and utils.andt(mapfsm(check_state, fsm, is_sta))
   res = res and utils.andt(mapfsm(check_trans, fsm, is_trans))
   return res, mes
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
      print("set fqn:", s._fqn)
   end

   fsm._fqn = fsm._id
   mapfsm(__add_fqn, fsm, is_node)
end

--------------------------------------------------------------------------------
-- resolve transition src and target strings into references of the real states
--    depends on fully qualified names
local function resolve_trans(fsm)

   -- three types of targets:
   --    1. local, only name given, no '.'
   --    2. relative, leading dot
   --    3. absolute, no leading dot

   local function __resolve_trans(tr, parent)

      --
      -- resolve path
      --
      local function __resolve_path(state_str, parent)
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
	 elseif string.sub(tr.src, 1, 1) == '.' then
	    -- leading dot, relative target
	    param.err("relative transitions not supported (and maybe never will!)")
	 else
	    -- absolute target, this is a fqn!
	    state = index_tree(fsm, utils.split(state_str, "[\\.]"))
	 end
	 return state, mes
      end

      -- resolve transition src
      local function __resolve_src(tr, parent)
	 local src, mes = __resolve_path(tr.src, parent)
	 if not src then
	    param.err("ERROR: resolving src failed " .. tostring(tr) .. ": " .. mes)
	    return false
	 else
	    if is_cplx(src) then
	       if src.final == nil then
		  param.err("ERROR: resolving src failed " .. tostring(tr) .. 
			 " src on cplx state boundary without final connector")
		  return false
	       end
	       tr.src = src.final
	    else
	       tr.src = src 
	    end
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

	 local tgt, mes = __resolve_path(tr.tgt, parent)

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

      return __resolve_src(tr, parent) and __resolve_tgt(tr, parent)
   end

   return utils.andt(mapfsm(__resolve_trans, fsm, is_trans))
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

   -- verify
   local ret, errs = verify(fsm)
   if not ret then
      param.err(table.concat(errs, '\n'))
      return false
   end

   if not resolve_trans(fsm) then
      param.err("failed to resolve transitions of fsm " .. fsm._id)
      return false
   end

   -- local event queue is empty
   fsm.evq = {}

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
      table.insert(fsm.equeue, v)
   end
end

--------------------------------------------------------------------------------
-- fetch all external events into local queue
local function update_evq(fsm)
   local new_ev = fsm.getevents()
   for _,v in ipairs(new_ev) do
      table.insert(fsm.evq, v)
   end
end


--------------------------------------------------------------------------------
-- run one doo functions of an active state and place it at the end of
-- the active queue
-- returns true if there is at least one active doo, otherwise false
local function run_doos(fsm)
   local has_run = false
   for i in 1,#fsm.actq do

      -- rotate
      local state = table.remove(fsm.actq, 1)
      table.insert(fsm.actq, state)

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
   state.mode = 'active'
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
   state._parent.act_child = 'false'
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

-- get least-common parallel ancestor
-- this function can be used to validate transitions.
-- Runtime: a transition to an active parallel state is invalid
-- Static: transition to a different region with the same LCPA is invalid
local function getLCPA(tr)
   -- tbd
end

--------------------------------------------------------------------------------
-- execute a simple transition
local function exec_trans(fsm, tr)
   -- paranoid check: sth would be very wrong if tgt is already active
   if tr.tgt.state ~= 'inactive' then
      param.err("ERROR: transition target " .. tr.tgt._fqn .. " in invalid state '" .. tr.tgt.state .. "'")
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
   while cur and  cur.state ~= 'inactive' do -- => 'dead' or 'active'
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
local function enter_fsm(fsm)
   fsm.state = 'active'
   local path = find_enabled_node(fsm, fsm.connectors['initial'], events)

   if #path == 0 then
      fsm.state = 'inactive'
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

   update_evq(fsm)

   -- entering fsm for the first time
   --
   -- it is impossible to exit it again, as there exist no transition
   -- targets outside of the FSM
   if fsm.state ~= 'active' then
      enter_fsm(fsm)
      idling = false
   elseif #fsm.evq > 0 then
      -- received events, attempt to transition
      if transition(fsm, fsm.evq) then
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


-- testing

-- define sets of input events and expected trajectory and test
-- against actually executed trajectory
--
