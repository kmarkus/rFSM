-- any rFSM is always contained in a composite_state
return rfsm.composite_state:new {
   dbg = true, -- enable debugging

   on = rfsm.composite_state:new {
      entry = function () print("disabling brakes") end,
      exit = function () print("enabling brakes") end,

      moving = rfsm.simple_state:new {
         entry=function () print("starting to move") end,
         exit=function () print("stopping") end,
      },

      waiting = rfsm.simple_state:new {},

      -- define some transitions
      rfsm.trans:new{ src='initial', tgt='waiting' },
      rfsm.trans:new{ src='waiting', tgt='moving', events={ 'e_start' } },
      rfsm.trans:new{ src='moving', tgt='waiting', events={ 'e_stop' } },
   },

   in_error = rfsm.simple_state:new {
      doo = function (fsm) 
                 print ("Error detected - trying to fix") 
                 rfsm.yield()
                 math.randomseed( os.time() )
                 rfsm.yield()
                 if math.random(0,100) < 40 then
                    print("unable to fix, raising e_fatal_error")
                    rfsm.send_events(fsm, "e_fatal_error")
                 else
                    print("repair succeeded!")
                    rfsm.send_events(fsm, "e_error_fixed")
                 end
              end,
   },

   fatal_error = rfsm.simple_state:new {},

   rfsm.trans:new{ src='initial', tgt='on', effect=function () print("initalizing system") end },
   rfsm.trans:new{ src='on', tgt='in_error', events={ 'e_error' } },
   rfsm.trans:new{ src='in_error', tgt='on', events={ 'e_error_fixed' } },
   rfsm.trans:new{ src='in_error', tgt='fatal_error', events={ 'e_fatal_error' } },
   rfsm.trans:new{ src='fatal_error', tgt='initial', events={ 'e_reset' } },
}