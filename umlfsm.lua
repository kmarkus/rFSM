--
--  Lua based UML 2.0 finite state machine engine
-- 

local pairs, ipairs, print, table, type, loadstring, assert
   = pairs, ipairs, print, table, type, loadstring, assert

module("umlfsm")

--
-- miscellaneous (local) helpers
--

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

local function eval(str)
   return assert(loadstring(str))()
end

-- do some rough integrity checking
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
   
   --  unknown table attributes -> e.g. detect typos

   -- all ok
   return true
end
   
   -- get current state optimize later with lookup table
function get_cur_state(fsm)
   return get_state_by_name(fsm, fsm.cur_state)
end

-- return a state specified by string
function get_state_by_name(fsm, name)
   local state = 
      filter(function (s)
		if s.name == name then
		   return true
		else return false
		end
	     end, fsm.states)
   return state[1]
end

-- transitions selection algorithm
function select_transition(state, event)
   transitions =
      filter(function (t)
		if t.event == event then
		   return true
		else return false
		end
	     end, state.transitions)
   if #transitions > 1 then
      fsm.warn("FSM Warning: multiple valid transitions found, using first (->", transitions[1].target, ")")
   end
   return transitions[1]
end


-- these checks should be moved to initalization 
-- and strings transformed to functions
function run_prog(p)
   if type(p) == "string" then 
      return eval(p)
   elseif type(p) == "function" then
      return p()
   else
      fsm.err("FSM Error: unknown program type: ", p)
      return false
   end
end

-- additional parameter: maxsteps required
-- returns number of steps performed
function step(fsm)
   local event = pick_event(fsm)
   
   if event == nil then
      fsm.dbg("FSM Debug: event queue empty")
      return false
   else 
      fsm.dbg("FSM Debug: got event: ", event)
   end
   
   local cur_state = get_cur_state(fsm)
   fsm.dbg("FSM Debug: cur_state: '" .. cur_state.name .. "'")

   local trans = select_transition(cur_state, event)
   
   if not trans then
      fsm.warn("FSM Warning: no transition for event '" .. event .. "' in state '" .. cur_state.name .. "' - dropping.")
      return true
   end

   fsm.dbg("FSM Debug: selected transition with target '" ..  trans.target .. "'")
   local new_state = get_state_by_name(fsm, trans.target)
   fsm.dbg("FSM Debug: new_state: '" .. new_state.name .. "'")

   if trans.guard then
      -- guard inhibits transition
      if not run_prog(trans.guard) then
	 return true
      end
   end
      
   -- execute transition:
   -- Run-to-completion step starts here
   if cur_state.exit then run_prog(cur_state.exit) end
   if trans.effect then run_prog(trans.effect) end
   if new_state.entry then run_prog(new_state.entry) end
   fsm.cur_state = new_state.name
   -- Run-to-completion step ends here

   -- this could be moved into a coroutine implementing history states
   -- and (voluntary) preemption ...later.
   if new_state.doo then run_prog(new_state.doo) end
   
   return true
end

-- do maximum max_steps stupersteps
-- return max_steps - steps done
function run(fsm, max_steps)
   if max_steps == 0 then
      return 0
   else
      if not step(fsm) then
	 return max_steps
      else
	 -- no tail call: return 1+ run(fsm, max_steps - 1)
	 return run(fsm, max_steps - 1)
      end
   end
end

-- get an event from the queue
function pick_event(fsm)
   -- tbd: take deferred events into account
   return table.remove(fsm.queue, 1)
end

-- store an event in the queue
function send(fsm, event)
   table.insert(fsm.queue, event)
end

-- initalize state machine
function init(fsm)

   -- setup logging
   local nullprint = function () return true end

   if not fsm.err then fsm.err = print end

   if fsm.no_warn then
      fsm.warn = nullprint
   else
      if not fsm.warn then fsm.warn = print end
   end
   
   if fsm.debug then 
      if not fsm.dbg then fsm.dbg = print end
   else
      fsm.dbg = nullprint
   end

   -- check integrity
   if not verify_fsm(fsm) then
      return false
   end

   if not fsm.queue then fsm.queue = {} end
   fsm.cur_state = fsm.initial_state

   return true
end
