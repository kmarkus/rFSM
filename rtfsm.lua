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
-- enter root state recursively
local function enter_root(fsm)
   fsm.state = 'active'
   local path = find_enabled(fsm, fsm.connectors['initial'], events)

   if #path == 0 then
      fsm.state = 'inactive'
      return false
   end

   exec_path(path)
   return true
end


--------------------------------------------------------------------------------
-- enter a state (and nothing else)
local function enter(fsm, state)
   if state.entry then state.entry(fsm, state) end
   state.mode = 'active'
   state.parent.act_child = state
end

--------------------------------------------------------------------------------
-- exit a state (and nothing else)
local function exit(fsm, state)
   -- save this for possible history entry
   if state.mode == 'active' then
      state.parent.last_active = state
   else
      state.parent.last_active = false
   end
   state.mode = 'inactive'
   state.parent.act_child = 'false'
   if state.exit then state.exit(fsm, state) end
end

--------------------------------------------------------------------------------
-- execute a simple transition
local function exec_trans(fsm, trans)
   local lca = getLCA(trans)  	-- if necessary, replace by cache later

   -- implicit exit all up to but excluding LCA
   -- run effect
   -- implicit enter from but excluding LCA to trans.tgt
   -- set fsm.act_leaves
end

--------------------------------------------------------------------------------
-- execute a compound transition
-- ct is a table of transitions
local function exec_ctrans(fsm, ct)
   utils.foreach(function (tr) exec_trans(fsm, tr) end, ct)
end

--------------------------------------------------------------------------------
-- check if transition is triggered by events and guard is true
local function is_enabled(tr, events)

end

--------------------------------------------------------------------------------
-- return all enabled paths starting with 'node'
-- backtracks, exponential complexity
-- inefficient but practical: returns a table of valid paths.
-- this means copying the existing path every step
local function check_path(node, tab)
   local function __check_path(tr)
      if not is_enabled(tr) then
	 return nil
      end

      local newtab = utils.deepcopy(tab)
      newtab[#tab+1] = tr

      if tr.tgt.type == 'simple' then return newtab
      else return check_path2(tr.tgt, newtab) end
   end
   return map(__check_path, node.otrs)
end

--------------------------------------------------------------------------------
-- find enabled path starting from 'node' enabled by 'events'
local function find_path(fsm, node, events)
   return check_path(fsm, node, events, {})
end

--------------------------------------------------------------------------------
-- attempt to transition the fsm
local function transition(fsm, events)
   -- walk down tree of active states and call find_enabled on each
   -- if one or more paths are returned, select one and call exec_trans
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
      enter_root(fsm)
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
      else return end
   end

   -- tail call
   return step(fsm)
end


-- testing

-- define sets of input events and expected trajectory and test
-- against actually executed trajectory
--
