                     The rFSM Statecharts (beta1)
                     ============================

Author: Markus Klotzbuecher
Date: [2011-02-10 Thu]




Table of Contents
=================
1 Overview 
2 Quickstart 
3 Introduction 
4 API 
    4.1 Model entities 
    4.2 Operational API 
    4.3 Hook functions 
5 Common pitfalls 
6 Tools 
7 Helper modules 
8 More examples, tips and tricks 
9 Acknowledgement 


1 Overview 
~~~~~~~~~~~

  rFSM is a small yet powerful Statechart implementation. It is mainly
  designed for /Coordinating/ of complex systems but not limited to
  that. rFSM is written purely in Lua and is thus highly portable and
  embeddable. As a Lua domain specific language rFSM inherits the
  extensibility of its host language.

  rFSM is dual licensed under LGPL/BSD.

2 Quickstart 
~~~~~~~~~~~~~

  1. define an rfsm state machine (see =examples/hello\_world.lua=)
  2. define a context script to execute it (see =examples/runscript.lua=)
  3. run it

  lua examples/runscript.lua
  INFO: created undeclared connector root.initial
  hello
  world
  hello
  world

3 Introduction 
~~~~~~~~~~~~~~~

  rFSM is a minimal Statechart variant designed for /Coordinating/
  complex systems such as robots. It is written purely in Lua and is
  thus highly portable and embeddable. Being a Lua domain specific
  language, rFSM inherits the easy extensibility of its host language.

  The following example shows a simple hello\_world example:


  return rfsm.composite_state:new {
     hello = rfsm.simple_state:new{ exit=function() print("hello") end },
     world = rfsm.simple_state:new{ entry=function() print("world") end },
  
     rfsm.transition:new{ src='initial', tgt='hello' },
     rfsm.transition:new{ src='hello', tgt='world', events={ 'e_done' } },
     rfsm.transition:new{ src='world', tgt='hello', events={ 'e_restart' } },
  }

  The first line defines a new toplevel composite state and returns
  it. By always returning the fsm as the last statement in an rfsm
  file, it can be very easily read by tools and reused.

  The second and third line define two simple states which are part of
  the toplevel composite state. hello defines and exit function and
  world and entry function which are called when the state is
  exited/entered resp.

  The next three lines define transition between these states. The
  first is from the initial connector to the hello state. This
  transition will be taken the first time the state machine is
  entered. The initial connector, as an exception, need not be defined
  and will be created automatically.

  The next transition is from hello to world and is triggered by the
  =e\_done= event. This event is raised internally when the a state
  completes, which is either the case when the states "doo" function
  (see below) finishes or immediately if there is no doo, as is the
  case here.

  Next we execute this statemachine in the rfsm-simulator:


  PMA-10-048 ~/prog/lua/rfsm(master) $ tools/rfsm-sim examples/hello_world.lua
  Lua 5.1.4  Copyright (C) 1994-2008 Lua.org, PUC-Rio
  rFSM simulator v0.1, type 'help()' to list available commands
  INFO: created undeclared connector root.initial
  > step()
  hello
  active: root.hello(done)
  queue:  e_done@root.hello

  We execute =step()= to advance the state machine once. As this is
  the first step, the fsm is entered via the 'initial' connector to
  the =hello= state. After that hello is active and =done= (because no
  doo function is defined). Consequently an =e\_done= completion event
  has been generated which is in the queue. So the next step...


  > step()
  world
  active: root.world(done)
  queue:  e_done@root.world

  ... causes a transtion to done. As the 'world' state completion
  event does not trigger any transitons, running =step()= again does
  not cause any changes:


  > step()
  active: root.world(done)
  queue:
  But we can manually send in the =e\_restart= event and call =step()=,
  which takes us back to =hello=:


  > se("e_restart")
  > step()
  hello
  active: root.hello(done)
  queue:  e_done@root.hello


4 API 
~~~~~~

4.1 Model entities 
===================

     Function                   short alias     description               
    --------------------------+---------------+--------------------------
     =simple\_state:new{}=      =sista:new{}=   create a simple state     
     =composite\_state:new{}=   =csta:new{}=    create a composite state  
     =connector:new{}=          =conn:new{}=    create a connector        
     =transition:new{}=         =trans:new{}=   create a transition       

   (these functions are part of the rfsm module, thus can be called
   in Lua with =rfsm.simple\_state{}=)

   1. states (=simple\_state= and =composite\_state=) may define the
      following programs:


  entry(fsm, state, 'entry')
  exit(fsm, state, 'exit')

      which are called when the state is entered exited or exited
      respectively. The argument passed in are the toplevel
      statechart, the current state and the string 'entry'
      resp. 'exit'. (The rationale behind the third argument is to
      allow one function to handle entry and exit and thus to be able
      to identify which one is being called.)

      Simple states may additionaly define a do function (it is called
      =doo= in to avoid clashes with the identically named Lua
      keyword).


  bool doo(fsm, state, 'doo')

      This function is called repetitively while a state remains
      active, that is no events trigger an outgoing transition and the
      do function has not yet completed. The bool return value defines
      wheter the doo is active or idle. In practice this means: if doo
      does not return true and there are no other events, doo will be
      called in a tight loop.

      As the doo function is created as a Lua coroutine, it is
      possible to suspend it at arbitray points by calling
      coroutine.yield()

   2. connector: =connector=

      Connectors allow to define so called compound transitions by
      chaining multiple transition segments together. Connectors are
      similar to the UML junction element and are statically
      checked. This means for a compound transition to be executed the
      events specified on all transitions must match the current
      events and the guards of all transitions must be true.

      See the examples =connector\_simple.lua= and =connector\_split.lua=

      Connectors are useful for defining common entry points which are
      later dispatched to various internal states.

      Note: defining cycles is possible, but dangerous, unsupported
      and discouraged.

   4. transitions: =transitions=

      Transitions define how the state machine changes states when
      events occur:

      example:


  rfsm.transition:new{ src='stateX',
                       tgt='stateY',
                       events = {"e1", "e2" },
                       effect=function () do_this() end }

      This defines a transition between stateX and stateY which is
      triggered by e1 _and_ e2 and which will execute the given effect
      function when transitioning.

      Three ways of specifying src and target states are supported:
      /local/, /relative/ or /absolute/. In the above example 'stateX'
      and 'stateY' are referenced locally and must therefore be
      defined within the same composite state as this transition.

      Relative references specify states which are, relative to the
      position of the transition, deeper nested. Such a reference
      starts with a leading dot. For example:


  return rfsm.csta:new{
     operational=rfsm.csta:new{
        motors_on = rfsm.csta:new{
           moving = rfsm.sista:new{},
           stopped = rfsm.sista:new{},
        },
     },
     off=rfsm.sista:new{},
     rfsm.trans:new{src='initial', tgt=".operational.motors_on.moving"}
  }

      This transition is defined between the (locally referenced)
      'initial' connector to the relatively referenced =moving= state.

      At last absolute references begin with "root." Using absolute
      syntax is strongly discouraged for anything other than testing,
      as it breaks compositionality: if a state machine is used with a
      larger statemachine the absolute reference is broken.

4.2 Operational API 
====================

     Function                        description                                           
    -------------------------------+------------------------------------------------------
     =fsm rfsm.init(fsmmodel)=       create an inialized rfsm instance from model          
     =idle rfsm.step(fsm, n)=        attempt to transition FSM n times. Default: once      
     =rfsm.run(fsm)=                 run FSM until it goes idle                            
     =rfsm.send\_events(fsm, ...)=   send one or more events to internal rfsm event queue  


   The =step= will attempt to step the given initialized fsm for n
   times. A step can either be a transition or a single execution of
   the doo program. Step will return either when the state machine is
   idle or the number of steps has been reached. The Boolean return
   value is whether the fsm is idle or not.

   Invoking =run= will call step as long as the fsm is not idle. Not idle
   means: there are events in the queue or there is an active =doo=
   function which is not idle.

4.3 Hook functions 
===================

   The following hook functions can be defined for a toplevel
   composite state and allow to refine various behavior of the state
   machine.

     function                   description                                                                       
    --------------------------+----------------------------------------------------------------------------------
     =dbg=                      called to output debug information. Set to false to disable. Default false.       
     =info=                     called to output informational messages. Set to false to disable. Default stdout  
     =warn=                     called to output warnings. Set to false to disable. Default stderr.               
     =err=                      called to output errors. Set to false to disable. Default stderr.                 
     =table getevents()=        function which returns a table of new events which have occurred                  
     =dropevents(fsm, evtab)=   function is called with events which are discarded                                
     =step\_hook(fsm)=          is called for each step (mostly for debugging purposes)                           
     =idle\_hook(fsm)=          called *instead* of returning from step/run functions                             

   The most important function is =getevents=. The purpose of this
   function is return all events which occurred in a table. This allows
   to integrate rFSM instances into any event driven environment.

5 Common pitfalls 
~~~~~~~~~~~~~~~~~~

  1. Name clashes between state/connector names with reserved Lua
     keywords.

     This can be worked around by using the following syntax:


  ['end'] = rfsm.sista{...}

  2. Executing functions accidentially

     It is a common mistake to execute externally defined functions
     instead of adding references to them:


  stateX = rfsm.sista{ entry = my_func() }

     The (likely) mistake above is to execute my_func and assigning the
     result to entry instead of assigning my_func:


  stateX = rfsm.sista{ entry = my_func }

     Of course the first example would be perfectly valid if my_func()
     returned a function as a result!

6 Tools 
~~~~~~~~
  - =rfsm-viz=
    simple tool which can generate images from state machines.

    to generate all possible formats run:


  rfsm-viz all examples/composite_nested.lua

  - =rfsm-sim=

    small command line simulator for running a fsm
    interactively.


  rfsm-viz all examples/ball_tracker_scope.lua

    It requires a image viewer which automatically updates once the
    file displayed changes. For example =evince= works nicely.

  - =rfsm2json= converts an lua fsm to a json representation. Requires
    lua-json.

  - =rfsm-dbg= experimental. don't use.

7 Helper modules 
~~~~~~~~~~~~~~~~~
  - =fsm2uml.lua= module to generate UML like figures from rFSM
  - =fsm2tree.lua= module to generate the tree structure of an rFSM instance
  - =fsmpp.lua= Lowlevel function used to improve the debug output.
  - =fsmtesting.lua= statemachine testing infrastructure.
  - =rfsm\_rtt.lua= Useful functions for using rFSM with OROCOS rtt
  - =fsmdbg.lua= a remote debugger interface which is simply still too
    experimental to be even documented.

8 More examples, tips and tricks 
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  - How to use the =doo= function as a coroutine:


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
  
     error = rfsm.simple_state:new {
        doo = function (fsm)
                   print ("Error detected - trying to fix")
                   coroutine.yield()
                   math.randomseed( os.time() )
                   coroutine.yield()
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
     rfsm.trans:new{ src='on', tgt='error', events={ 'e_error' } },
     rfsm.trans:new{ src='error', tgt='on', events={ 'e_error_fixed' } },
     rfsm.trans:new{ src='error', tgt='fatal_error', events={ 'e_fatal_error' } },
     rfsm.trans:new{ src='fatal_error', tgt='initial', events={ 'e_reset' } },
  }

  - How to include other state machines

    this is easy! Let's assume the state machine is is a file
    "subfsm.lua" and uses the strongly recommended =return
    rfsm.csta:new ...= syntax, it can be included as follows:


  return rfsm.csta:new {
  
     name_of_composite_state = dofile("subfsm.lua"),
  
     otherstateX = rfsm.sista{},
     ...
  }

    Make sure not to forget the ',' after the =dofile()= statement!

9 Acknowledgement 
~~~~~~~~~~~~~~~~~~

  - Funding

    The research leading to these results has received funding from
    the European Community's Seventh Framework Programme
    (FP7/2007-2013) under grant agreement no. FP7-ICT-231940-BRICS
    (Best Practice in Robotics)

  - Scientific background

    This work borrows many ideas from the Statecharts by David Harel
    and some ideas from UML 2.1 State Machines. The following
    publications are the most relevant

    David Harel and Amnon Naamad. 1996. The STATEMATE semantics of
    statecharts. ACM Trans. Softw. Eng. Methodol. 5, 4 (October 1996),
    293-333. DOI=10.1145/235321.235322
    [http://doi.acm.org/10.1145/235321.235322]

    The OMG UML Specification:
    [http://www.omg.org/spec/UML/2.3/Superstructure/PDF/]
