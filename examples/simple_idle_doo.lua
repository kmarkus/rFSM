--
-- Extremly simply state machine with two states shows the effect of
-- the doo idle flag (the return value of rfsm.yield(). When true
-- as for on the statemachine will assume no work needs to be done and
-- go idle (if there are no other events). Thus step or run need to be
-- called to run the doo. In contrast the doo of the 'off' state does
-- not return doo idle and therefore is (automatically) repeatedly
-- called while no other events are in the queue
--

return rfsm.csta {
   on = rfsm.sista {
      doo=function(fsm)
	     for i=1,5 do
		print("hello ".. i .. " from on")
		rfsm.yield(true)
	     end
	  end
   },

   off = rfsm.sista{
      entry=function() print("entering off") end,

      doo=function(fsm)
	     for i=1,10 do
		print("hello ".. i .. " from off")
		rfsm.yield()
	     end
	  end
   },

   rfsm.trans{ src='off', tgt='on', events={ 'e_on' } },
   rfsm.trans{ src='on', tgt='off', events={ 'e_done' } },
   rfsm.trans{ src='initial', tgt='off' }
}
