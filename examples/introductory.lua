-- any rFSM is always contained in a composite_state
local state, conn, trans = rfsm.state, rfsm.conn, rfsm.trans

return state {
   dbg = true, -- enable debugging

   on = state {
      entry = function () print("disabling brakes") end,
      exit = function () print("enabling brakes") end,

      moving = state {
         entry=function () print("starting to move") end,
         exit=function () print("stopping") end,
      },

      waiting = state {},

      -- define some transitions
      trans{ src='initial', tgt='waiting' },
      trans{ src='waiting', tgt='moving', events={ 'e_start' } },
      trans{ src='moving', tgt='waiting', events={ 'e_stop' } },
   },

   in_error = state {
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

   fatal_error = state {},

   trans{ src='initial', tgt='on', effect=function () print("initalizing system") end },
   trans{ src='on', tgt='in_error', events={ 'e_error' } },
   trans{ src='in_error', tgt='on', events={ 'e_error_fixed' } },
   trans{ src='in_error', tgt='fatal_error', events={ 'e_fatal_error' } },
   trans{ src='fatal_error', tgt='initial', events={ 'e_reset' } },
}