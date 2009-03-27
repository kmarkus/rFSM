--
-- simple lua UML 2.0 state machine
-- 

function verify_fsm(fsm)
   -- checks:
   --  no duplicate states
   --  no transitions to invalid states
   --  unknown table attributes -> e.g. detect typos
   --  each fsm has initial_state
   --  each state has a name
   --  each transition has target
   return true
end

-- debugging helpers
function dbg(...) return nil end

-- function dbg(...)
--    arg.n = nil
--    io.write("DEBUG: ")
--    map(function (e) io.write(e, " ") end, arg)
--    io.write("\n")
-- end

function warn(...)
   arg.n = nil
   io.write("WARN: ")
   map(function (e) io.write(e, " ") end, arg)
   io.write("\n")
end

function err(...)
   arg.n = nil
   io.write("ERROR: ")
   map(function (e) io.write(e, " ") end, arg)
   io.write("\n")
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
      warn("multiple valid transitions found, using first (->", transitions[1].target, ")")
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
      err("unknown program type: ", p)
      return false
   end
end

-- additional parameter: maxsteps required
-- returns number of steps performed
function step(fsm)
   local event = pick_event(fsm)
   
   if event == nil then
      dbg("event queue empty")
      return false
   else 
      dbg("got event: ", event)
   end
   
   local cur_state = get_cur_state(fsm)
   dbg("cur_state: ", table.tostring(cur_state))

   local trans = select_transition(cur_state, event)
   
   if not trans then
      warn('no transition for event', event, 'in state', cur_state.name, '- dropping.')
      return true
   end

   dbg("selected transition: ", table.tostring(trans))
   local new_state = get_state_by_name(fsm, trans.target)
   dbg("new_state: ", table.tostring(new_state))

   if trans.guard then
      if not run_prog(trans.guard) then
	 return true
      end
   end
      
   -- execute transition:
   -- RTCS starts here
   if cur_state.exit then run_prog(cur_state.exit) end
   if trans.effect then run_prog(trans.effect) end
   if new_state.entry then run_prog(new_state.entry) end
   fsm.cur_state = new_state.name
   -- RTCS ends here

   -- this could be moved into a coroutine implementing history states
   -- and (voluntary) do preemption ...later.
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
   if not fsm.queue then fsm.queue = {} end
   fsm.cur_state = fsm.inital_state
end

-- imports
dofile("../mylib/misc.lua")
dofile("../mylib/functional.lua")

-- run argv[1]
if #arg < 1 then
   print("usage:", arg[0], "<fsm file>")
   os.exit(1)
end

dofile(arg[1])
