
require ('utils')

local pairs, ipairs, utils, table, map, filter, tostring, type =
pairs, ipairs, utils, table, utils.map, utils.filter, tostring, type

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

-- tbdel:
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

function is_sista(s) return type(s) == 'table' and s:type() == 'simple' end
function is_csta(s) return type(s) == 'table' and s:type() == 'composite' end
function is_psta(s) return type(s) == 'table' and s:type() == 'parallel' end
function is_conn(s) return type(s) == 'table' and s:type() == 'connector' end
function is_trans(s) return type(s) == 'table' and s:type() == 'transition' end
function is_join(s) return type(s) == 'table' and s:type() == 'join' end
function is_fork(s) return type(s) == 'table' and s:type() == 'fork' end

function is_sta(s) return is_sista(s) or is_csta(s) or is_psta(s) end
function is_cplx(s) return is_csta(s) or is_psta(s) end
function is_node(s) return is_sta(s) or is_conn(s) end

-- apply func to all fsm elements for which pred returns true
function mapfsm(func, fsm, pred)
   local res = {}
   
   local function __mapfsm(states)
      map(function (s, k)
	     if k ~= '__parent' then  -- filter parent links or we'll cycle forever
		if pred(s) then
		   res[#res+1] = func(s, states, k)
		end 
		if is_cplx(s) then
		   __mapfsm(s)
		end
	     end
	  end, states)
   end
   __mapfsm(fsm)
   return res
end

-- tbddel:
-- -- apply func to all substates of fsm
-- function map_state(func, fsm, checkf)
--    local res = {}
--    local function __map_state(states, parent)
--       map(function (s)
-- 	     if checkf(s) then
-- 		res[#res+1] = func(s, parent)
-- 	     end
-- 	     __map_state(filter(is_sta, s), s)
-- 	  end,
-- 	  states)
--    end

--    checkf = checkf or function(s) return true end

--    -- is child state predicate (=not parent links, functions, metadata, ...)
--    local function is_childsta(state, parent)
--       return is_sta(s) and s ~= parent
--    end

--    __map_state(filter(is_childsta, fsm), fsm)
--    return res
-- end

-- -- apply func(trans, cstate) to all transitions
-- -- cstate is state which owns the transitions (thus not necessarily
-- -- the containing state)
-- function map_trans(func, fsm, checkf)
--    local function __map_trans(transitions, state)
--       map(function (t)
-- 	     if checkf(t) then
-- 		res[#res+1] = func(t, state)
-- 	     end
-- 	  end, transitions)
--    end

--    local res = {}
--    checkf = checkf or function(s) return true end
--    __map_trans(filter(is_trans, fsm), fsm)
--    map_state(function (s)
-- 		__map_trans(filter(is_trans, s), s)
-- 	     end, fsm)
--    return res
-- end

-- tbdel:
-- apply func to all substates of fsm
-- function map_state(func, fsm, checkf)
--    local function __map_state(states, tab)
--       map(function (state)
-- 	     if checkf(state) then
-- 		local res = func(state)
-- 		table.insert(tab, res)
-- 	     end
-- 	     __map_state(state.states, tab)
-- 	     __map_state(state.parallel, tab)
-- 	  end,
-- 	  states)
--    end

--    local res = {}
--    checkf = checkf or function(s) return true end
--    __map_state(fsm.states, res)
--    __map_state(fsm.parallel, res)
--    return res
-- end

-- tbdel:
-- apply func(trans, cstate) to all transitions
-- cstate is state which owns the transitions
-- function map_trans(func, fsm)
--    local function __map_trans(transitions, state, tab)
--       map(function (t)
-- 	     local res = func(t, state)
-- 	     table.insert(tab, res)
-- 	  end, transitions)
--    end

--    local tab = {}
--    __map_trans(fsm.transitions, fsm, tab)
--    map_state(function (s)
-- 		__map_trans(s.transitions, s, tab)
-- 	     end, fsm)
--    return tab
-- end
