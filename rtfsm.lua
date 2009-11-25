--------------------------------------------------------------------------------
--  Lua based robotics finite state machine engine
--------------------------------------------------------------------------------

require ('utils')
require ('fsmutils')

param = {}
param.err = print
param.warn = print
param.dbg = print

-- save references

local param, pairs, ipairs, print, tostring, table, string, type,
loadstring, assert, coroutine, setmetatable, getmetatable, utils,
fsmutils = param, pairs, ipairs, print, tostring, table, string,
type, loadstring, assert, coroutine, setmetatable, getmetatable,
utils, fsmutils

module("rtfsm")

local map = utils.map
local foldr = utils.foldr
local AND = utils.AND
local tab2str = utils.tab2str
local map_state = fsmutils.map_state
local map_trans = fsmutils.map_trans

--------------------------------------------------------------------------------
-- perform checks
-- test should bark loudly about problems and return false if
-- initialization is to fail
-- depends on parent links for more useful output
function verify(fsm)

   -- test: check if state has an id
   local function check_id(s)
      if not s.id then
	 if s.parent and s.parent.id then
	    param.err("ERROR: child state of '" .. s.parent.id .. "' without id")
	 else
	    param.err("ERROR: state without id found")
	 end
	 return false
      else
	 return true
      end
   end

   local function check_trans(t, parent)
      local ret = true
      local errors = {}
      if not t.src then
	 table.insert(errors, "missing source state")
	 ret = false
      end
      if not t.tgt then
	 table.insert(errors, "missing target state")
	 ret = false
      end
      -- tbd: event
      if not ret then
	 param.err("Transition ERROR(s) in " .. fsmutils.tr2str(t) .. ", parent is '" .. parent.id .. "' :")
	 map(function (e) param.err("", e) end, errors)
      end
      return ret
   end

   -- run checks
   local res = true

   if type(fsm) ~= 'table' then
      param.err("ERROR: fsm is not a table")
      res = false
   end

   if not fsm.id then
      param.warn("WARNING: root fsm has no id, setting to 'root'")
      fsm.id = 'root'
   end

   res = res and foldr(AND, true, map_state(check_id, fsm))
   res = res and foldr(AND, true, map_trans(check_trans, fsm))

   return res
end

--------------------------------------------------------------------------------
-- construct parent links
-- this modifies fsm
local function add_parent_links(fsm)
   local function __add_pl(states, parent)
      if not states or #states == 0 then return end

      for i,k in ipairs(states) do
	 k.parent=parent
	 __add_pl(k.states, k)
	 __add_pl(k.parallel, k)
      end
   end

   fsm.parent = fsm

   __add_pl(fsm.states, fsm)
   __add_pl(fsm.parallel, fsm)
end

--------------------------------------------------------------------------------
-- add fully qualified names (fqn) to states
-- depends on parent links beeing available
local function add_fqn(fsm)
   fsm.fqn = fsm.id -- root
   map_state(function (s) s.fqn = s.parent.fqn .. "." .. s.id end, fsm)
end

--------------------------------------------------------------------------------
-- create a (fqn, state) lookup table
-- and return a lookup function and a table of duplicates
local function fqn2st_cache(fsm)
   local cache = {}
   local dupl = {}

   cache[fsm.id] = fsm
   cache['root'] = fsm

   map_state(function (s)
		if cache[s.fqn] then dupl[#dupl+1] = s.fqn
		else cache[s.fqn] = s end end,
	     fsm)

   return function (fqn) return cache[fqn] end, dupl
end

--------------------------------------------------------------------------------
-- resolve transition src and target strings into references of the real states
--    depends on local uniqueness
--    depends on fully qualified names
--    depends on lookup table
local function resolve_trans(fsm)

   -- three types of targets:
   --    1. local, only name given, no '.'
   --    2. relative, leading dot
   --    3. absolute, no leading dot

   local function __resolve_trans(tr, parent)
      -- resolve path
      local function __resolve_path(state_str, parent)
	 local state
	 if not string.find(state_str, '[\\.]') then
	    -- no dots, local state
	    local state_fqn = parent.fqn .. '.' .. state_str
	    state = fsm.fqn2st(state_fqn)
	 elseif string.sub(tr.src, 1, 1) == '.' then
	    -- leading dot, relative target
	    print("WARNING: relative transitions not supported and maybe never will!")
	 else
	    -- absolute target, this is a fqn!
	    state = fsm.fqn2st(state_str)
	 end
	 return state
      end

      -- resolve transition src
      local function __resolve_src(tr, parent)
	 local ret = true
	 if tr.src == 'initial' then
	    parent.initial = tr
	 else -- must be a path
	    local src = __resolve_path(tr.src, parent)
	    if not src then
	       param.err("ERROR: unable to resolve transition src " .. tr.src .. " in " .. fsmutils.tr2str(tr))
	       ret = false
	    else tr.src = src end end
	 return ret
      end

      -- resolve transition tgt
      local function __resolve_tgt(tr, parent)
	 local ret = true
	 -- resolve target
	 if tr.tgt == 'internal' then
	    param.warn("WARNING: internal events not supported yet")
	 elseif tr.tgt =='final' then
	    -- leave it
	 else
	    local tgt = __resolve_path(tr.tgt, parent)
	    if not tgt then
	       param.err("ERROR: unable to resolve transition tgt " .. tr.tgt .. " in " .. fsmutils.tr2str(tr))
	       ret = false
	    else tr.tgt = tgt end end
	 return ret
      end

      return __resolve_src(tr, parent) and __resolve_tgt(tr, parent)
   end

   return utils.andt(map_trans(__resolve_trans, fsm))
end

--------------------------------------------------------------------------------
-- create a state -> outgoing transition lookup cache
local function st2otr_cache(fsm)
   local cache = {}

   map_trans(function (tr, parent)
		if not cache[tr.src] then cache[tr.src] = {} end
		table.insert(cache[tr.src], tr)
	     end, fsm)

   return function(srcfqn) return cache[srcfqn] end
end

--------------------------------------------------------------------------------
-- initialize fsm
-- create parent links
-- create table for lookups
function init(fsm_templ)

   local fsm = utils.deepcopy(fsm_templ)

   add_parent_links(fsm)

   if not verify(fsm) then
      param.err("failed to initalize fsm " .. fsm.id);
      return false
   end

   add_fqn(fsm)

   -- build fqn->state cache and check for duplicates
   do
      local dupl
      fsm.fqn2st, dupl = fqn2st_cache(fsm)
      if #dupl > 0 then
	 param.err("ERROR: duplicate fully qualified state names:\n",
		   table.concat(dupl, '\n'))
      end
   end

   if not resolve_trans(fsm) then
      param.err("failed to resolve transitions of fsm " .. fsm.id)
      return false
   end

   -- build state->outgoing-transition lookup function
   fsm.st2otr = st2otr_cache(fsm)

   -- local event queue is empty
   fsm.evq = {}

   -- getevents user hook supplied?
   -- must return a table with events
   if not fsm.getevents then
      fsm.getevents = function () return {} end
   end

   -- All OK!
   fsm.__initalized = true
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
   state.parent.act_child = state
   -- tbd: act_leaves, parallel states
end

--------------------------------------------------------------------------------
-- exit a state (and nothing else)
local function exit_state(state)
   -- save this for possible history entry
   if state.mode == 'active' then
      state.parent.last_active = state
   else
      state.parent.last_active = false
   end
   state.mode = 'inactive'
   state.parent.act_child = 'false'
   if state.exit then state.exit(state) end
end

-- this function exploits the fact that the LCA is the first parent of
-- tgt which is in state 'active'
-- tbd: sure this works for parallel states?
local function getLCA(tr)
   local lca = trans.tgt.parent
   -- looks dangerous, but root should always be active:
   while lca ~= 'active' do
      lca = lca.parent
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
      param.err("ERROR: transition target " .. tr.tgt.fqn .. " in invalid state '" .. tr.tgt.state .. "'")
   end

   local lca = getLCA(trans)
   local state_walker = tr.src

   --  exit all states from src up to (but excluding) LCA
   while state_walker ~= lca do 
      exit_state(state)
      state_walker = state_walker.parent
   end

   -- run effect
   tr.effect(fsm, tr)

   -- implicit enter from (but excluding) LCA to trans.tgt
   -- tbd: create walker function: foreach_[up|down](start, end, function)
   local down_path = {}
   local state_walker = trans.tgt

   while state_walker ~= lca do
      table.insert(down_path, state_walker)
      state_walker = state_walker.parent
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
      if fsm.idle then fsm.idle(fsm)
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
