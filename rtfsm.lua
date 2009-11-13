--
--  Lua based robotics finite state machine engine
--

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

-- add fully qualified names (fqn) to states
-- depends on parent links beeing available
local function add_fqn(fsm)
   fsm.fqn = fsm.id -- root
   map_state(function (s) s.fqn = s.parent.fqn .. "." .. s.id end, fsm)
end

-- create a (fqn, state) lookup table
-- add duplicates to __dupl entry
local function build_lt(fsm)
   local tab = {}
   tab['dupl'] = {}

   tab[fsm.id] = fsm

   map_state(function (s)
		if tab[s.fqn] then
		   param.err("ERROR: duplicate fully qualified name " .. s.fqn .. " found!")
		   table.insert(tab['dupl'], s.fqn)
		else
		   tab[s.fqn] = s
		end
	     end, fsm)
   if #tab['dupl'] == 0 then
      tab['dupl'] = nil
      return tab
   else
      return false
   end
end


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
	    state = fsm.lt[state_fqn]
	 elseif string.sub(tr.src, 1, 1) == '.' then
	    -- leading dot, relative target
	    print("WARNING: relative transitions not supported and maybe never will!")
	 else
	    -- absolute target, this is a fqn!
	    print("looking up absolute tgt=" .. state_str)
	    state = fsm.lt[state_str]
	 end
	 return state
      end

      -- resolve transition src
      local function __resolve_src(tr, parent)
	 local ret = true
	 if tr.src == 'initial' then
	    -- ok
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

   fsm.lt = build_lt(fsm)
   if not fsm.lt then return false end

   if not resolve_trans(fsm) then
      param.err("failed to resolve transitions of fsm " .. fsm.id)
      return false
   end

   fsm.__initalized = true
   return fsm
end

--
-- operational functions
--

-- calculate the transition trajectory, which is the path of states
-- between the source and the target state
--
-- part1 is defined by: up the active tree up to the LCA (exiting)
-- part2 is defined by: down from LCA to tgt (entering). Only the
-- entering part is returned by calc_trans
--
-- Random idea: what if there were multiple but different possible
-- trajectories? different ways to achieve sth? -> Think about
-- alternative visualization of FSM
--
local function calc_trans_trj(fsm, src, tgt)
   -- create sth like
   -- { src, tgt, lca, part2 }
end


-- determine first enabled transition to take given a table of events
--
-- for each state starting from root, check if the list of events
-- triggers a transition from an active state and (if existant) it's
-- guard condition evaluates to false.
--
local function find_en_tr(fsm, events)

end

local function exec_trans(fsm, trans)
end

-- execute one microstep, ie one single state exit and entry
function microstep(fsm)

end


-- perform a run to completion step which will, at least, cause the
-- fsm to run until it has reached an stable configuration. It may run
-- longer if no event become available and the currently active state
-- has a doo program
--
-- a fsm can be in to states: stable or in-transition which is
-- represented by the variable
-- fsm.stable = true or false
--
-- if it's stable it can react to new events, otherwise not. If stable
-- is nil then the fsm has not been entered yet (which is an unstable
-- state because it can not react to events before the initial
-- transition has been executed.
--
function rtcstep(fsm)
   -- 1. find valid transitions
   --    1.1. get list of events
   --	 1.2 apply them top-down to active configuration

   -- 2. execute the transition
   --    2.1 find transition trajectory
   --    2.2 execute it
end
