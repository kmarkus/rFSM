--
--  Lua based UML 2.1 finite state machine engine
-- 

local pairs, ipairs, print, table, type, loadstring, assert, coroutine
   = pairs, ipairs, print, table, type, loadstring, assert, coroutine

module("umlfsm")

--
-- miscellaneous (local) helpers
--

-- recursively print table
function print_tab(tab, indstr, indnum)
   table.foreach(tab, function (i, v)
			 print(string.rep(indstr, indnum) .. i,v)
			 if type(v) == 'table' then
			    print_tab(v, indstr, indnum + 1)
			 end
		      end)
end

-- create a dictionary of states
local function get_state_dict(fsm)
   local dict = {}
   for i,s in ipairs(fsm.states) do
      if s.name then dict[s.name] = s end
   end
   return dict
end

local function map(f, tab)
   local newtab = {}
   for i,v in pairs(tab) do
      res = f(v)
      table.insert(newtab, res)
   end
   return newtab
end

local function filter(f, tab)
   local newtab= {}
   for i,v in pairs(tab) do
      if f(v) then
	 table.insert(newtab, v)
      end
   end
   return newtab
end

local function foldr(func, val, tab)
   for i,v in pairs(tab) do
      val = func(val, v)
   end
   return val
end

local function AND(a, b)
   return a and b
end

local function eval(str)
   return assert(loadstring(str))()
end

-- precompile strings for speed
function precompile_fsm(fsm)
   function precompile_state(state)
      function pc_str(str)
	 if str and type(str) ~= "function" then
	    local f = loadstring(str)
	    if f then
	       str = f
	       return true
	    else
	       fsm.err("FSM Error: failed to precompile program string: '" .. str .. "'")
	       return false end end end
      
      -- precompile all transition effects
      if not foldr(AND, true, map(function (trans) 
				     pc_str(trans.effect)
				  end, state.transitions)) then
	 return false
      end
      
      return pc_str(state.entry) and pc_str(state.doo) and pc_str(state.exit)
   end

   return foldr(AND, true, map(precompile_state, fsm.states))

end

--
-- do some rough integrity checking
--
function verify_fsm(fsm)

   --  each fsm has initial_state
   if not fsm.initial_state then
      fsm.err("FSM Error: no initial_state defined.")
      return false
   end

   local nodupl = {}
   local state_dict = get_state_dict(fsm)
   
   for i,state in ipairs(fsm.states) do

      -- check for nameless states
      if not state.name or state.name == "" then
	 fsm.err("FSM Error: state #" .. i .. " without name")
	 return false
      end

      -- check for composite without initial
      if state.states and not state.initial then
	 fsm.err("FSM Error: composite state " .. state.name .. " lacks initial state")
      end

      -- check for identically named states
      if nodupl[state.name] then
	 fsm.err("FSM Error: states " .. nodupl[state.name] .. " and " .. i ..  " with same name '"..  state.name .. "'")
      else
	 nodupl[state.name] = i
      end

      -- check for states without outgoing transitions
      if not state.transitions then
	 fsm.warn("FSM Warning: no outgoing transitions from state '" .. state.name .. "'")
      else
	 -- check for invalid transition targets
	 for i,trans in ipairs(state.transitions) do
	    if not state_dict[trans.target] then
	       fsm.err("FSM Error: in state '" .. state.name .. "' unknown transition target state '" .. trans.target .. "'")
	       return false
	    end
	 end
      end
   end
   
   --  unknown table attributes -> e.g. detect typos tbd

   -- all ok
   return true
end

-- find least common ancestor
local function find_LCA(fsm, s1, s2)
end

-- resolve all string transition targets
local function resolve_links(fsm)
end

-- add 'parent' links to FSM tree
local function add_parent_links(child, parent)
   child.parent = parent
   if child.states then
      table.foreach(function (state)
		       add_parent_links(state, child)
		    end,
		    child.states)
   end
end

-- these checks should be moved to initalization 
-- and strings transformed to functions
local function run_prog(fsm, p)
   if type(p) == "string" then 
      return eval(p)
   elseif type(p) == "function" then
      return p()
   else
      fsm.err("FSM Error: unknown program type: ", p)
      return false
   end
end

-- return a state specified by string
local function get_state_by_name(fsm, name)
   local state = 
      filter(function (s)
		if s.name == name then
		   return true
		else return false
		end
	     end, fsm.states)
   return state[1]
end

-- get current state optimize later with lookup table
local function get_cur_state(fsm)
   return get_state_by_name(fsm, fsm.cur_state)
end

-- get an event from the queue
local function pick_event(fsm)
   -- tbd: take deferred events into account
   return table.remove(fsm.queue, 1)
end

-- get an event from the queue
local function has_events(fsm)
   return #fsm.queue
end

-- transitions selection algorithm
-- tbd: check guard conditions
local function select_transition(fsm, state, event)
   transitions =
      filter(function (t)
		if t.event == event then
		   if t.guard then 
		      return run_prog(fsm, t.guard)
		   else 
		      return true
		   end
		else
		   return false
		end
	     end, state.transitions)
   if #transitions > 1 then
      fsm.warn("FSM Warning: multiple valid transitions found, using first (->", transitions[1].target, ")")
   end
   return transitions[1]
end


-- perform the atomic transition to a new state
-- returns: true if transitioned (at least once), false otherwise
local function run_to_completion(fsm, event)
   
   if not event then return false end
   
   local cur_state = get_cur_state(fsm)
   fsm.dbg("FSM Debug: cur_state: '" .. cur_state.name .. "'")

   local trans = select_transition(fsm, cur_state, event)
   
   if not trans then
      fsm.warn("FSM Warning: no transition for event '" .. event .. "' in state '" .. cur_state.name .. "' - dropping.")
      return false
   end

   fsm.dbg("FSM Debug: selected transition with target '" ..  trans.target .. "'")
   local new_state = get_state_by_name(fsm, trans.target)
   fsm.dbg("FSM Debug: new_state: '" .. new_state.name .. "'")

   -- execute transition:
   -- Run-to-completion step starts here
   if cur_state.exit then run_prog(fsm, cur_state.exit) end
   if trans.effect then run_prog(fsm, trans.effect) end
   if new_state.entry then run_prog(fsm, new_state.entry) end
   fsm.cur_state = new_state.name
   -- Run-to-completion step ends here
   return true
end

function enter(root, state)
   root.dbg("FSM Debug: entering " .. state.name)
   run_prog(root, state.entry)
   state.active = true

   -- if composite, continue
   if not state.states then
      table.insert(root.al, state)
      return
   else
      
   end
end

function exit(root, state)
   root.dbg("FSM Debug: exiting " .. state.name)
   run_prog(root, state.exit)
   state.active = false
end

--
-- advance the state machine
--
function step(root)

   -- if no states are active we must enter the fsm
   if #root.actstack == 0 then 
      enter(root)
   else
      if not run_to_completion(root, pick_event(fsm)) then
	 return false
      end
   end
   
   --    local new_state = get_cur_state(fsm)
   --    print("FSM Debug: now in state: " .. new_state.name)
   --    -- proper doo with voluntary preemption
   --    if new_state.doo then
   --       local co = coroutine.create(new_state.doo)
   --       while has_events(fsm) == 0 do
   -- 	 coroutine.resume(co)
   -- 	 if coroutine.status(co) == "dead" then
   -- 	    break
   -- 	 end
   --       end
   --    end
   return step(fsm)
end

-- store an event in the queue
function send(fsm, event)
   table.insert(fsm.queue, event)
end

-- initalize state machine
function init(fsm)

   -- setup logging
   local nullprint = function () return true end

   fsm.err = fsm.err or print

   if fsm.no_warn then
      fsm.warn = nullprint
   else
      fsm.warn = fsm.warn or print
   end
   
   if fsm.debug then 
      fsm.dbg = fsm.dbg or print
   else
      fsm.dbg = nullprint
   end

   -- check integrity
   if not verify_fsm(fsm) then
      return false
   end

   if not precompile_fsm(fsm) then
         return false
   end

   -- event queue is empty
   if not fsm.queue then fsm.queue = {} end

   -- active stack is empty
   fsm.actstack = {}

   return true
end
