--
-- Extremly simply state machine with two states shows the effect of
-- the doo idle flag (the return value of coroutine.yield(). When true
-- as for on the statemachine will assume no work needs to be done and
-- go idle (if there are no other events). Thus step or run need to be
-- called to run the doo. In contrast the doo of the 'off' state does
-- not return doo idle and therefore is (automatically) repeatedly
-- called while no other events are in the queue
--

return rfsm.csta:new {
   on = rfsm.sista:new {
      doo=function(fsm)
	     for i=1,5 do
		print("hello ".. i .. " from on")
		coroutine.yield(true)
	     end
	  end
   },

   off = rfsm.sista:new{
      entry=function() print("entering off") end,

      doo=function(fsm)
	     for i=1,10 do
		print("hello ".. i .. " from off")
		coroutine.yield()
	     end
	  end
   },

   rfsm.trans:new{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans:new{ src='on', tgt='off', events={ 'e_done' } },
   rfsm.trans:new{ src='initial', tgt='off' }
}
