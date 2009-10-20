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
local function map_pstate(func, fsm)
   local function __map_pstate(f, state, tab)
      local tmp = f(state)
      table.insert(tab, tmp)
      if state.states then
	 map(function (s) __map_pstate(f, s, tab) end, state.parallel)
      end
      return tab
   end

   return __map_pstate(func, fsm, {})
end


-- apply func to all composite states
local function map_cstate(func, fsm)

   local function __map_cstate(f, state, tab)
      local tmp = f(state)
      table.insert(tab, tmp)
      if state.states then
	 map(function (s) __map_cstate(f, s, tab) end, state.states)
      end
      return tab
   end

   return __map_cstate(func, fsm, {})
end

-- apply func to all states incl. fsm itself
local function map_state(func, fsm)
   return utils.append(map_cstate(func, fsm),
		       map_pstate(func, fsm))
		       
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
-- cst stands for composite state
local function add_fqn(fsm)
   fsm.fqn = fsm.id
   map_state(function (s)
		s.fqn = s.parent.id .. "." .. s.id
	     end, fsm)
end

	   
-- resolve transition targets
-- depends on fully qualified names
local function resolve_trans(fsm)
   
end

-- construct a name->{state,depth} lookup table (lut).
local function build_namecache(fsm, tab, parid, depth)
   if not tab then -- toplevel
      lut = {}
      -- two ways to address root
      lut['root'] = { state=fsm, depth=0 }
      lut[fsm.id] = { state=fsm, depth=0 }
      map(function (state) 
	     build_namecache(state, lut, parid, 1)
	  end,
	  fsm.states)
   else -- deeper levels
      -- 
   end   

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
