--
--  Lua based robotics finite state machine engine
-- 

require ('utils')

param = {}
param.err = print
param.warn = print
param.dbg = print

-- save references

local param, pairs, ipairs, print, table, type, loadstring, assert,
coroutine, setmetatable, getmetatable, utils = param, pairs, ipairs,
print, table, type, loadstring, assert, coroutine, setmetatable,
getmetatable, utils

module("rtfsm")

local map = utils.map
local foldr = utils.foldr
local AND = utils.AND
local tab2str = utils.tab2str

-- makestate creates a state from a template
-- variables in vartab will override those in templ
function make_state(templ, vartab)
   local ns = utils.deepcopy(templ)
   for k,v in pairs(vartab) do
      ns[k] = v
   end
   return ns
end


--
-- local map helpers
--

-- apply func to all parallel states
local function map_pstate(func, fsm, excl_parent)
   local function __map_pstate(f, state, tab)
      local tmp = f(state)
      table.insert(tab, tmp)
      if state.states then
	 map(function (s) __map_pstate(f, s, tab) end, state.parallel)
      end
      return tab
   end
   if excl_parent then
      return utils.flatten( map(function(s) __map_pstate(func, s, {}) end, fsm.parallel))
   else
      return __map_pstate(func, fsm, {})
   end
end


-- apply func to all composite states
local function map_cstate(func, fsm, excl_parent)

   local function __map_cstate(f, state, tab)
      local tmp = f(state)
      table.insert(tab, tmp)
      if state.states then
	 map(function (s) __map_cstate(f, s, tab) end, state.states)
      end
      return tab
   end
   
   if excl_parent then
      return utils.flatten( map(function(s) __map_cstate(func, s, {}) end, fsm.states))
   else
      return __map_cstate(func, fsm, {})
   end
end

-- apply func to all states incl. fsm itself
local function map_state(func, fsm, excl_parent)
   return utils.append(map_cstate(func, fsm, excl_parent),
		       map_pstate(func, fsm, excl_parent))
end

-- apply func to all transitions
local function foreach_trans(fsm, func)
end

-- perform checks
-- test should bark loudly about problems and return false if
-- initialization is to fail
-- depends on parent links for more useful output
function verify(fsm)
   local res = true

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

   res = res and foldr(AND, true, map_state(check_id, fsm))
   
   return res
end

-- construct parent links
-- this modifies fsm
local function add_parent_links(fsm)
   fsm.parent = fsm
   map_state(function (fsm)
		map(function (state)
		       state.parent = fsm
		       return true
		    end, fsm.states)
	     end, fsm)

   map_state(function (fsm)
		map(function (state)
		       state.parent = fsm
		       return true
		    end, fsm.parallel)
	     end, fsm)
end

-- add fully qualified names (fqn) to states
-- depends on parent links beeing available
local function add_fqn(fsm)
   local function __add_fqn(s) 
      s.fqn = s.parent.fqn .. "." .. s.id 
      print("setting fqn=" .. s.fqn .. "=" .. s.id )
   end
   fsm.fqn = fsm.id
   print("setting root fqn=" .. fsm.fqn .. "=" .. fsm.id )
   map_state(__add_fqn, fsm, true)
end

-- create a (fqn, state) lookup table
local function build_lt(fsm)
   local tab = {}
   tab['dupl'] = {}
   
   map_state(function (s) 
		print("checking fqn=" .. s.fqn)
		if tab[s.fqn] then
		   param.err("ERROR: duplicate fully qualified name " .. s.fqn .. " found!")
		   table.insert(tab['dupl'], s.fqn)
		else
		   print("adding to lt: " .. s.fqn)
		   tab[s.fqn] = s
		end
	     end, fsm)
   if #tab['dupl'] == 0 then tab['dupl'] = nil end
   return tab
end

	   
-- resolve transition targets
-- depends on fully qualified names
local function resolve_trans(fsm)
   
end

local function reset(fsm)
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
   else
      add_fqn(fsm)
      map_state(function (s) print("fqn: ", s.fqn) end, fsm)
      map_state(function (s) print("id : ", s.id) end, fsm)
      fsm.lt = build_lt(fsm)
      if fsm.lt.dupl then return false end
      table.foreach(fsm.lt, print)
   end

   return fsm
end

--
-- operational functions
-- 

-- find least common ancestor
local function findLCA(fsm, sx, sy)
   
end

-- determine transition to take given a table of events
local function find_trans(fsm, events)
end

local function exec_trans(fsm, lca, src, target)
end

function step(fsm)
   exec_trans(find_trans(fsm, fsm.queue))
end
