--
--  Lua based robotics finite state machine engine
--

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

local function tr2str(tr)
   local t = {}
   if tr.tgt == 'internal' then
      t[1] = "type: internal"
      t[2] = "src: " .. tr.src
      t[3] = "event: " .. tr.event
   elseif tr.src == 'initial' then
      t[1] = "type: initial"
      t[2] = "tgt: " .. tr.tgt
   elseif tr.tgt == 'final' then
      t[1] = "type: final"
      t[2] = "src: " .. tr.src
      t[3] = "event: " .. tr.event
   else
      t[1] = "type: regular"
      t[2] = "src: " .. tr.src
      t[3] = "tgt: " .. tr.tgt
      t[4] = "event: " .. tr.event
   end
   return table.concat(t, ', ')
end

--
-- local map helper
--

-- apply func to all substates of fsm
local function map_state(func, fsm, checkf)
   local function __map_state(states, tab)
      map(function (state)
	     if checkf(state) then
		local res = func(state)
		table.insert(tab, res)
	     end
	     __map_state(state.states, tab)
	     __map_state(state.parallel, tab)
	  end,
	  states)
   end

   local res = {}
   checkf = checkf or function(s) return true end
   __map_state(fsm.states, res)
   __map_state(fsm.parallel, res)
   return res
end

-- apply func(trans, cstate) to all transitions
-- cstate is state which owns the transitions
local function map_trans(func, fsm)
   local function __map_trans(transitions, state, tab)
      map(function (t)
	     local res = func(t, state)
	     table.insert(tab, res)
	  end, transitions)
   end

   local tab = {}
   __map_trans(fsm.transitions, fsm, tab)
   map_state(function (s)
		__map_trans(s.transitions, s, tab)
	     end, fsm)
   return tab
end

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


-- resolve transition targets
--    depends on local uniqueness
--    depends on fully qualified names
--    depends on lookup table
local function resolve_trans(fsm)
   -- three types of targets:
   --    1. local, only name given, no '.'
   --    2. relative, leading dot
   --    3. absolute, no leading dot

   local function __resolve_trans(tr, parent)

      if tr.tgt == 'internal' then
	 -- hmm
      elseif not string.find(tr.tgt, '[\\.]') then
	 -- no dots, local target
	 local tgtname = parent.fqn .. '.' .. tr.tgt
	 local tgt = fsm.lt[tgtname]
	 if not tgt then
	    param.err("ERROR: unable to resolve transition target, fqn: " .. tgtname .. ", " .. tr2str(tr))
	 end
      elseif string.sub(tr.tgt, 1, 1) == '.' then
	 -- leading dot, relative target
	 print("relative trans tgt not supported yet")
      else
	 -- absolute target
	 print("absolute trans tgt not supported yet")
      end
   end
   
   map_trans(__resolve_trans, fsm)

   return true
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

-- perform a run to completion step
function rtc_step(fsm)
   -- 1. find valid transitions
   --    1.1.

   -- 2. execute the transition
   --    2.1 find transition trajectory
   --    2.2 execute it
end
