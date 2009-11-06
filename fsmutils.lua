
require ('utils')

local pairs, ipairs, utils, table, map, tostring = pairs, ipairs,
utils, table, utils.map, tostring

module ('fsmutils')

-- makestate creates a state from a template
-- variables in vartab will override those in templ
function make_state(templ, vartab)
   local ns = utils.deepcopy(templ)
   for k,v in pairs(vartab) do
      ns[k] = v
   end
   return ns
end

function tr2str(tr)
   local t = {}
   if tr.tgt == 'internal' then
      t[1] = "type: internal"
      t[2] = "src: " .. tostring(tr.src)
      t[3] = "event: " .. tostring(tr.event)
   elseif tr.src == 'initial' then
      t[1] = "type: initial"
      t[2] = "tgt: " .. tostring(tr.tgt)
   elseif tr.tgt == 'final' then
      t[1] = "type: final"
      t[2] = "src: " .. tostring(tr.src)
      t[3] = "event: " .. tostring(tr.event)
   else
      t[1] = "type: regular"
      t[2] = "src: " .. tostring(tr.src)
      t[3] = "tgt: " .. tostring(tr.tgt)
      t[4] = "event: " .. tostring(tr.event)
   end
   return table.concat(t, ', ')
end

--
-- local map helper
--

-- apply func to all substates of fsm
function map_state(func, fsm, checkf)
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
function map_trans(func, fsm)
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
