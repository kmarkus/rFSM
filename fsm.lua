--
-- simple lua UML 2.0 state machine
-- 

function verify_fsm(fsm)
   -- checks:
   --  no duplicate states
   --  no transitions to invalid states
   --  unknown table attributes -> e.g. detect typos
   return true
end

-- get current state
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
      print("multiple valid transitions found, using first")
   end
   return transitions[1]
end

-- additional parameter: maxsteps required
-- returns number of steps performed
function step(fsm)
   local event = pick_event(fsm)
   
   if event == nil then
      print("event queue empty")
      return 0
   else 
      print("got event: ", event)
   end
   
   local cur_state = get_cur_state(fsm)
   print("cur_state: ", table.tostring(cur_state))

   local trans = select_transition(cur_state, event)

   -- execute transitions
   
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
   fsm.queue = {}
   fsm.cur_state = fsm.inital_state
end

-- imports
dofile("../mylib/misc.lua")
dofile("../mylib/functional.lua")

-- sample statemachine
fsm = { 
   inital_state = "off", 
   states = { { 
		 name = "on", 
		 entry = "print('entry on')", 
		 doo = "print('inside on do')", 
		 exit = "print('inside on exit')", 
		 transitions = { { event="off-button", target="on" } } },
	      { 
		 name = "off", 
		 entry = "print('entry on')", 
		 doo = "print('inside on do')", 
		 exit = "print('inside on exit')",
		 transitions = { { event="on-button", target="on" } } } 
	   } 
}


-- here we go
-- eval(fsm.states.name)
init(fsm)
send(fsm, "on-button")
send(fsm, "off-button")
step(fsm)
step(fsm)


