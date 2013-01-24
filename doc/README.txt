@<img src="./rFSM_logo.jpg" width="71%" height="70%" title="rFSM Statecharts" alt="rFSM Statecharts" /@> @<br/@>@<br/@>v1.0
===========================================================================================================================

Author: Markus Klotzbuecher
Date: 2012-02-20



Table of Contents
=================
1 Overview
2 Setup
3 Introduction
4 Specifying rFSM models
    4.1 States (=rfsm.state=)
        4.1.1 The doo function
        4.1.2 Configuring a State Machine
    4.2 Transitions (=rfsm.transition=)
    4.3 Connector (=rfsm.connector=)
5 Executing rFSM models
6 Common pitfalls
7 Tools and helper modules
    7.1 The event memory extension (=rfsm_emem= module) #EventMemory
    7.2 Await: trigger transition only after receiving multipe events
    7.3 Timeevents (=rfsm_timeevent= module)
    7.4 Configurable and colorized =dbg= info (=rfsmpp= module)
    7.5 =rfsm_checkevents= plugin
    7.6 Generate graphical representations (=rfsm2uml= and =fsm2dbg= modules)
    7.7 =rfsm-viz=: command line front end to rfsm2uml/rfsm2tree
    7.8 =rfsm-sim= simple rfsm simulator
    7.9 Lua fsm to json conversion (=rfsm2json= command line tool)
    7.10 =rfsm_rtt= Useful functions for using rFSM with OROCOS rtt
8 More examples, tips and tricks
    8.1 A more complete example
    8.2 How to compose state machines
    8.3 Using rfsm with Orocos RTT
9 API Summary
    9.1 State specification
    9.2 Operational functions
    9.3 Hooks
10 Contact
11 Download
12 Acknowledgement


1 Overview 
-----------

  rFSM is a small and powerful Statechart implementation. It is mainly
  designed for /Coordination/ of complex systems but is not limited to
  that. rFSM is written in pure Lua and is therefore highly portable
  and embeddable. As a Lua domain specific language rFSM inherits the
  extensibility of its host language.

  rFSM is dual licensed under LGPL/BSD.

  This README is also available in HTML and Text format in the doc/
  subdirectory.


2 Setup 
--------

  Make sure you have Lua 5.1 installed and the rFSM folder is in your
  =LUA_PATH=. For example:



  export LUA_PATH=";;;/home/mk/src/git/rfsm/?.lua"


  If your =LUA_PATH= is already set to something, then just add the
  rFSM path instead of overwriting it:



  export LUA_PATH="$LUA_PATH;/home/mk/src/git/rfsm/?.lua"



3 Introduction 
---------------

  rFSM is minimal Statechart flavour designed for /Coordinating/ of
  complex systems such as robots. It has the following features:

  - Hierarchical (composite) states
  - Completion events
  - Parametrizable and reusable states
  - Easy to build statemachines by composing existing states/state machines
  - Plugin mechanism permits extending the core engine. Available
    plugins include timeevents, event memory, sequential AND states
    and more.
  - Real-time safe operation possible using lua-tlsf/rtp[1]

  The following shows a simple hello_world example



    [file:example1.png]



  1:  return rfsm.state {
  2:     hello = rfsm.state { exit=function() print("hello") end },
  3:     world = rfsm.state { entry=function() print("world") end },
  4:  
  5:     rfsm.transition { src='initial', tgt='hello' },
  6:     rfsm.transition { src='hello', tgt='world', events={ 'e_done' } },
  7:     rfsm.transition { src='world', tgt='hello', events={ 'e_restart' } },
  8:  }


  The first line defines a new toplevel composite state and returns
  it. The root state of an rFSM state machine is always a state
  itself. This permits it to be composed as a substate in a different
  state machine. The =return= statement facilitates reading rfsm model
  files by tools or other state machines.

  The second and third line define two leaf states that are part of
  the toplevel composite state. =hello= defines an exit function and
  world an entry function which are called when the state is
  exited/entered, respectively.

  The next three lines define transition between these states. The
  first is from the initial connector to the =hello= state. This
  transition will be taken the first time the composite state is
  entered. The initial connector, as an exception, need not be defined
  and will be created automatically when referenced from a transition.

  The next transition is from =hello= to =world= and is triggered by
  the =e_done= event. This event is raised internally when a state
  completes, which is either the case when the states 'doo' function
  (see below) finishes or immediately, if there is no =doo=, as is the
  case here. The third transition is triggered by the =e_restart=
  event.

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
  the =hello= state. After that the state =hello= is active and =done=
  (because no =doo= function is defined). Consequently, an =e_done=
  completion event has been generated and placed in the queue. So the
  next step...



  > step()
  world
  active: root.world(done)
  queue:  e_done@root.world


  ... causes a transition to =world=. As the =world= state completion
  event does not trigger any transitons, running =step()= again does
  not have any effect:



  > step()
  active: root.world(done)
  queue:


  But we can manually send in the =e_restart= event and call =step()=,
  which takes us back to =hello=:



  > se("e_restart")
  > step()
  hello
  active: root.hello(done)
  queue:  e_done@root.hello



4 Specifying rFSM models 
-------------------------

  rFSM state machines are constructed using three model elements:
  *states*, *connectors* and *transitions*.

  (all functions are part of the rfsm module, thus need to be called
  in Lua with the =rfsm= prefix, e.g. =rfsm.state{}=)

4.1 States (=rfsm.state=) 
==========================

   States are used to model discrete states of the system and can be
   either composite or leaf states. A composite state contains other
   states, while a leaf state does not. States can define =entry= and
   =exit= functions



  entry(fsm, state, 'entry')
  exit(fsm, state, 'exit')


   that are called when the state is entered or exited
   respectively. The arguments passed in are the toplevel statechart,
   the current state and the string 'entry' resp. 'exit'. Normally
   you don't need these arguments and should not change them
   either. (The rationale behind the second and third argument is to
   permit one function to handle entry and exit of multiple states
   and hence needs to identify these).


4.1.1 The doo function 
~~~~~~~~~~~~~~~~~~~~~~~

    Leaf states may additionaly define a do function (it is called
    =doo= in rFSM to avoid clashes with the identically named Lua
    keyword).



  bool doo(fsm, state, 'doo')


    The doo function is used to perform actions /while/ a leaf state
    is active. To that end it can be used such that it is repeatedly
    called until either the function completes or an event triggers a
    transition to a different state.

    Implementationwise, this function is treated as a Lua
    coroutine. This enables the following two use-cases:

     1. =doo= is a regular function: =doo= is excuted once and a
        completion event =e_done= is raised afterwards (if no =doo=
        function is defined this event is raised immediately after
        execution of the =entry= function).

     2. Long running =doo= with voluntary preemption: while possible,
        it is not recommended to define a =doo= function that runs for
        a longer time, because this would prevent incoming events to
        trigger transitions. Therefore, the =rfsm.yield()= call can be
        inserted at appropriate points into a long running =doo= to
        explicitely return control to the rfsm engine, that then
        checks for new events and potentially executes transitions.

    (Note: rfsm.yield is currently only an alias to =coroutine.yield=)

    The following example illustrates the second use case:



  doo = function(fsm)
           while true do
              if min_distance() < 0.1 then
                 rfsm.send_events(fsm, "e_close_obj")
              end
              rfsm.yield()
           end
        end


    This =doo= will check a certain condition repeatedly and raise the
    "e_close_obj" event if it is true. Each cycle the control is
    returned to the rFSM core by calling =rfsm.yield()=.

    =rfsm.yield(idle_flag)= accepts a boolean argument (called the
    "idle flag") that influences how =doo= is called by the rFSM core:
    if =true= it will cause the rFSM core to go idle, provided there
    are no other events. If =false= (the default[2] if no arguments
    are given) and there are no other events, =doo= will be called in
    a tight loop. It depends on each application which =idle_flag= is
    appropriate. In general the idle_flag should always be true unless
    the intention is that the =doo= function is executed as fast as
    possible (potentially consuming a lot of CPU!).


4.1.2 Configuring a State Machine 
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    The root composite state honors some extra fields to refine the
    global FSM behavior.

    *Configuring error, warning, informational and debug output.* The
    =err=, =warn=, =info= and =dbg= fields can be used to fine tune
    how these messages are output. The value of these fields can be
    either true or false or set to a function that accepts a variable
    list of arguments. The default is to write errors and warnings to
    stderr and info to stdout. Debug messages are turned off by
    default. Nicer and configurable pretty printing of debug output is
    provided by the =rfsmpp= module (described below).

    *The* =getevents= *hook.* The =getevents= hook is called by the
    rFSM core whenever it needs to check for new events. This function
    is the central mechanism to integrate rFSM into existing
    systems. The expected behavior is to return a Lua table of events
    (array part only). These events are then used to check for enabled
    transtions.

4.2 Transitions (=rfsm.transition=) 
====================================

   Transitions define how a state machine changes state upon receiving
   events:

   Example:



  rfsm.transition {
      src='stateX', tgt='stateY', events = {"e1", "e2"},
      guard=function()
                if getVal() > 0.3 then
                    return false
                end
                return true
            end,
      effect=function () do_this() end
  }


   The above defines a transition between stateX and stateY which is
   triggered by the events =e1= _and_ =e2=. The =guard= condition
   (optional) will prevent the transition from being executed if it
   returns false. The =effect= function (optional) will be executed
   during the transitioning of the function. If no events are
   specified, this is interpreted as *any* events will trigger the
   transition.

   Three ways of specifying the =src= and =target= states are
   supported: /local/, /relative/ or /absolute/. In the above example
   =stateX= and =stateY= are referenced locally and must therefore be
   defined within the same composite state as the transition.

   Relative references specify states that are more deeply nested
   (relative to the position of the transition). Such references
   starts with a leading dot. For example:



  return rfsm.state{
     operational=rfsm.state{
        motors_on = rfsm.state{
           moving = rfsm.state{},
           stopped = rfsm.state{},
           rfsm.trans{src='initial', tgt='stopped'},
        },
        rfsm.trans{src='initial', tgt='motors_on'},
     },
     off=rfsm.state{},
     rfsm.trans{src='initial', tgt=".operational.motors_on.moving" }
     rfsm.trans{src=".operational.motors_on.stopped", tgt='off', events={'e_off'} }
  }


   The first transition is defined between the (locally referenced)
   =initial= connector to the relatively referenced =moving=
   state. This permits to /refine/ the default behavior of the
   operational state, namely entering =motors_on.stopped= (due to the
   initial connectors), to instead enter the =motors_on.moving= state.

   The second transition defines a transition from the relatively
   referenced =operational.motors_on.stopped= to =off=. Here the
   intention is to constrain the states from which one can reach the
   =off= state: turning the device off is only permitted if it is not
   moving.

   At last absolute references begin with "root." Using absolute
   syntax is strongly discouraged for anything other than testing,
   as it breaks compositionality: if a state machine is used within
   a larger statemachine the absolute reference is broken.

   Furthermore, transitions support so called *priority
   numbers*. Priority numbers serve to resolve conflicts within one
   hierarchical level. In case two transitions are enabled by a set of
   events, the transition with the higher priority number will be
   executed. Priority numbers are defined with the =pn= keyword on
   transitions, as shown below. Transitions without priority numbers
   are assumed to have priority 0.



  rfsm.trans{ src='following', tgt='hitting', pn=10, events={ 't6' } },


   If possible, statecharts should be designed not to depend on
   priority numbers and introduce these rather as an optimization.

4.3 Connector (=rfsm.connector=) 
=================================

   Connectors permit to define so called compound transitions by
   chaining multiple transition segments together. Connectors are
   similar to the UML junction element. Compound transitions are
   statically evaluated, meaning that the compound transition is only
   executed if each subtransition is enabled (events match and guards
   are true).

   Also see the examples =connector_simple.lua= and
   =connector_split.lua=.

   Connectors are useful for defining interfaces (entry and exit
   points) that hide internals of a composite state. The following
   example defines a error handling state:


  return rfsm.state{
    software_err = rfsm.state{},
    hardware_err = rfsm.state{},
  
    initial = rfsm.conn{},
    recovered = rfsm.conn{},
    failed = rfsm.conn{},
  
    rfsm.trans{src='initial', tgt='software_err', events={'e_sw_err'}},
    rfsm.trans{src='initial', tgt='hardware_err', events={'e_hw_err'}},
  
    rfsm.trans{src='software_err', tgt='recovered', events={'e_recovered'}},
    rfsm.trans{src='hardware_err', tgt='recovered', events={'e_recovered'}},
    rfsm.trans{src='software_err', tgt='failed', events={'e_failed'}},
    rfsm.trans{src='hardware_err', tgt='failed', events={'e_failed'}},
  }


   Transitions 1 and 2 dispatch to different error handling states
   based on the events received. Transitions 3, 4, 5 and 6 connect the
   states to different exit connectors based on the events they
   generate.

   /Note/: defining cycles is possible, but dangerous, unsupported and
   discouraged. It may make the yoghurt in your fridge grow fine grey
   beards.


5 Executing rFSM models 
------------------------

  Before running a statemachine must be initalized. This serves to
  validate the fsm model and transform the fsm to be suitable for
  execution. Initalization is done using the =rfsm.init(fsm)=
  function, that takes a (string) rfsm description as input and
  returns an initalized fsm. To load an rfsm from a file and initalize
  it, the =rfsm.load(filename)= function can be used:



  fsm = rfsm.init(rfsm.load("fsm.lua"))


  If the return value from =rfsm.init= is not =false=, initalization
  succeeded and the returned fsm can be run.

  The function =rfsm.step(fsm, n)= will attempt to step the given fsm
  for a maximum of =n= times. A /step/ can be either the execution of
  a transition _or_ a single execution of the =doo= program. =step=
  will return either when the state machine is /idle/ _or_ the given
  number of steps has been reached. The boolean return value indicates
  whether the fsm is idle (=true=) or the maximum amount of requested
  steps was reached (=false=).

  For each step the rfsm engine will invoke the =getevents= hook to
  retrieve new events and then reason about what to do (which
  transitions to execute or =doo='s to run). After that these events
  are disgarded. If this seems inconvenient, checkout the [event memory]
  extension.

  When omitted, the number of steps argument =n= to =rfsm.step=
  defaults to *1*.

  =rfsm.run(fsm)= calls =step= as long as the given fsm is not
  idle. Not idle means: there are either events in the queue or there
  is an active =doo= function that is _not_ idle.

  To directly send events to the fsm the function
  =rfsm.send_events(fsm, e1, e2, ...)= can be used. The first argument
  is the fsm to which all subsequent event arguments are sent to.



  [event memory]: sec-7-1

6 Common pitfalls 
------------------

  1. Name clashes between state/connector names with reserved Lua
     keywords.

     This can be worked around by using the following syntax:



  ['end'] = rfsm.state{...}


  2. Executing functions accidentially

     It is a common mistake to execute externally defined functions
     instead of adding references to them:



  stateX = rfsm.state{ entry = my_func() }


     The (likely) mistake above is to execute my_func and assigning
     the result to entry instead of assigning my_func:



  stateX = rfsm.state{ entry = my_func }


     Of course the first example would be perfectly valid if
     my_func() returned a function as a result!

  3. Why doesn't my statemachine react if I send a completion event
     =e_done= from the outside?

     Short anwer: because it is a syntactic shortcut for the
     completion event *of the source state* of the transition which it
     is defined on. During initalization it is transformed to
     =e_done@fqn= (e.g. =e_root@root.stateA.stateB=) If you send in
     the expanded completion event it will work.

     Explanation: a completion event only makes sense in the context
     of a state which completed. Making the state which has completed
     explicit in the event avoids accidentially triggering a
     transition labeled with a higher priority completion event that
     has nothing to do with the current one.

     The same holds true for =rfsm_timeevent= based timeevents.

  4. My FSM is using up 100% CPU, what's wrong?

     Most likely you have defined a long running =doo= function that
     does not call =rfsm.yield= with a =true= argument (the idle
     flag). Therefore the rFSM engine calls the =doo= function in a
     tight loop.

  5. My FSM is doing nothing, my guard are not executed, ... ,
     although I'm running =step= or =run= periodically!

     rFSM will only attempt to transition if it has at least one event
     in the queue! If you only want to transition based on guards,
     raise a dummy event (e.g. "e_any").


7 Tools and helper modules 
---------------------------

7.1 The event memory extension (=rfsm_emem= module) #EventMemory 
=================================================================

   This extension adds /memory/ of events that occured to an rFSM
   statechart. This is done maintaining a table =emem= for every
   state. The keys in this table are event names and the values the
   number of times that event occurred while the respective state was
   active. The =emem= table is cleared when a state is exited by
   setting all values to 0.

   This extension is useful for defining transitions that are taken
   only after certain events have occured, but that do not necessarily
   occur within one step. Because the rFSM engine drops events after
   each steps this information would otherwise be lost.

   To enable event memory, all you need to do is load the =rfsm_emem=
   module. Checkout the =examples/emem_test.lua= for more details.


7.2 Await: trigger transition only after receiving multipe events 
==================================================================

   In a nutshell, this plugin permits to trigger transitions only
   after multiple events have been received. These events can be
   received in different steps.

   This is basically a specialized version of the emem plugin. This
   one should be preferred if no counting is required, since it is
   computationally much less expensive.

   Behavior: When loaded, the plugin scans for events with the syntax
   await(event1, event2)". This statement is transformed as follows:

    - a guard condition is generated and added to possibly existing
      guard conditions. It will only enable the transition if the both
      events have been received while the source state is active.

    - a second hook is installed in the exit function of the source
      state to reset the event counting. So when the source state is
      exited (either via or not via the await transition) and
      reentered again, the counting start from the beginning. It would
      be trivial to provide a variant of await that resets the counts
      only if the await transition is taken, however it is not clear
      right now if that would be useful at all.

   For more information checkout the =await.lua= example.

7.3 Timeevents (=rfsm_timeevent= module) 
=========================================

   This module extends the rFSM engine with time events. Time events
   are automatically raised /after/ the specified time after entering
   a state has elapsed. To enable time events, it suffices to load the
   =rfsm_timeevent= module. Currently only relative (opposed to
   absolute) timeevents are supported. These can be specified on
   transitions using the =e_done(duration)= syntax, as show in the
   following example:



  rfsm.trans{ src='A', tgt='B', events={ 'e_after(0.1)' } },


   The timeevent will be raised 100ms after state =A= was entered.

   The only requirement of a rfsm_timeevents is that a =gettime=
   function is configured using the
   =rfsm_timeevent.set_gettime_hook(f)= function. This function is
   expected to return the current time in two return values: seconds,
   nanoseconds.

   An example can be found in =examples/timeevent.lua=

   *Warning:* these timeevents only work while the rfsm engine is
    running and can not magically wake up an idle fsm. Therefore this
    type of timeevents typically only makes sense for fsm that are
    "stepped" at a fixed frequency or that never go idle.


7.4 Configurable and colorized =dbg= info (=rfsmpp= module) 
============================================================

   The =rfsmpp.gen_dbgcolor= function generates a configurable and
   colorful =dbg= hook.

   Usage:



  rfsmpp.gen_dbgcolor(name, dbgids, defshow)


     - =name= is the (optional) string name to print prefixing the
       debug output
     - =dbgids= is a table that enables or disables certain dbg ids by
       setting them to true or false. Known debug ids are:
       =STATE_ENTER=, =STATE_EXIT=, =EFFECT=, =DOO=, =EXEC_PATH=,
       =ERROR=, =HIBERNATING=, =RAISED=, =TIMEEVENT=
     - =defshow= (bool) defines wether debug id's not mentioned in the dbgids
       table are shown or not.


   Example:



  fsm = rfsm.init(...)
  fsm.dbg=rfsmpp.gen_dbgcolor("fsm1",
                              { STATE_ENTER=true, STATE_EXIT=true}, false)


   Will show only =STATE_ENTER= and =STATE_EXIT= debug messages.

7.5 =rfsm_checkevents= plugin 
==============================

   This debugging helper plugin will at load-time construct a list of
   all events used in the FSM. If at runtime an event is received
   which is not known in the known list, a warning message will be
   printed.

   To use, just require the modeule before creating your
   fsm. Important: load it /after/ other plugins that transform events
   (such as timevents), so that it picks up the transformed events.


7.6 Generate graphical representations (=rfsm2uml= and =fsm2dbg= modules) 
==========================================================================

     Modules to transform rFSM models to graphical
     descriptions. =rfsm2uml= generates classical statechart figures and
     =rfsm2tree= generates a tree representation (useful to see check
     priorities).

     Usage:

     - =rfsm2uml.rfsm2uml(root_fsm, format, outfile, caption)=
     - =rfsm2tree.rfsm2tree(root_fsm, format, outfile)=

     Examples:



  require("rfsm2uml")
  fsm = rfsm.init(rfsm.load("fsm.lua"))
  rfsm2uml.rfsm2uml(fsm, 'png', "fsm.png", "Figure caption")


     or



  require("rfsm2tree")
  fsm = rfsm.init(rfsm.load("fsm.lua"))
  rfsm2tree.rfsm2tree(fsm, 'png', "fsm-tree.png")


     The =rfsm-viz= command line uses these modules to generate
     pictures.


7.7 =rfsm-viz=: command line front end to rfsm2uml/rfsm2tree 
=============================================================

     to generate all possible formats run:



  $ tools/rfsm-viz all examples/composite_nested.lua


     generates various representations (in =examples/=)


7.8 =rfsm-sim= simple rfsm simulator 
=====================================

     small command line simulator for running a fsm
     interactively.



  $ tools/rfsm-sim all examples/ball_tracker_scope.lua


     It requires an image viewer which automatically updates once the
     file displayed changes. For example =evince= works nicely.


7.9 Lua fsm to json conversion (=rfsm2json= command line tool) 
===============================================================

   Based on =rfsm2json.lua= module and requires lua-json.


7.10 =rfsm_rtt= Useful functions for using rFSM with OROCOS rtt 
================================================================

   See the Orocos [LuaCookbook] for more details.



   [LuaCookbook]: http://www.orocos.org/wiki/orocos/toolchain/LuaCookbook

8 More examples, tips and tricks 
---------------------------------

8.1 A more complete example 
============================

   The graphical model:



      [file:example2.png]

   ... and the corresponding textual representation:



  -- any rFSM is always contained in a state
  return rfsm.state {
     dbg = true, -- enable debugging
  
     on = rfsm.state {
        entry = function () print("disabling brakes") end,
        exit = function () print("enabling brakes") end,
  
        moving = rfsm.state {
           entry=function () print("starting to move") end,
           exit=function () print("stopping") end,
        },
  
        waiting = rfsm.state {},
  
        -- define some transitions
        rfsm.trans{ src='initial', tgt='waiting' },
        rfsm.trans{ src='waiting', tgt='moving', events={ 'e_start' } },
        rfsm.trans{ src='moving', tgt='waiting', events={ 'e_stop' } },
     },
  
     error = rfsm.state {
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
  
     fatal_error = rfsm.state {},
  
     rfsm.trans{ src='initial', tgt='on',
                 effect=function() print("initalizing system") end },
     rfsm.trans{ src='on', tgt='error', events={ 'e_error' } },
     rfsm.trans{ src='error', tgt='on', events={ 'e_error_fixed' } },
     rfsm.trans{ src='error', tgt='fatal_error', events={ 'e_fatal_error' } },
     rfsm.trans{ src='fatal_error', tgt='initial', events={ 'e_reset' } },
  }



8.2 How to compose state machines 
==================================

   This is easy! Let's assume the state machine is is a file
   "subfsm.lua" and uses the strongly recommended =return
   rfsm.state ...= syntax, it can be included as follows:



  return rfsm.state {
  
     name_of_state = rfsm.load("subfsm.lua"),
  
     otherstateX = rfsm.state{},
     ...
  }


   Make sure not to forget the ',' after the =rfsm.load()= statement!


8.3 Using rfsm with Orocos RTT 
===============================
   The [LuaCookbook] page describes how to do this.



   [LuaCookbook]: http://www.orocos.org/wiki/orocos/toolchain/LuaCookbook

9 API Summary 
--------------

9.1 State specification 
========================

   Functions to define rFSM:

     *Function*       *Short alias*   *Description*        
    ----------------+---------------+---------------------
     =state{}=        =state{}=       create a state       
     =connector{}=    =conn{}=        create a connector   
     =transition{}=   =trans{}=       create a transition  



9.2 Operational functions 
==========================

     *Function*                     *Description*                                         
    ------------------------------+------------------------------------------------------
     =fsm rfsm.init(fsmmodel)=      create an initialized rfsm instance from model        
     =idle rfsm.step(fsm, n)=       attempt to transition FSM n times. Default: once      
     =rfsm.run(fsm)=                run FSM until it goes idle                            
     =rfsm.send_events(fsm, ...)=   send one or more events to internal rfsm event queue  


9.3 Hooks 
==========

   The following hook functions can be defined for a toplevel
   composite state and allow to refine various behavior of the state
   machine.

     *Function*            *Description*                                                                       
    ---------------------+------------------------------------------------------------------------------------
     =dbg=                 called to output debug information. Set to false to disable. Default: false.        
     =info=                called to output informational messages. Set to false to disable. Default: stdout.  
     =warn=                called to output warnings. Set to false to disable. Default stderr.                 
     =err=                 called to output errors. Set to false to disable. Default stderr.                   
     =table getevents()=   function which returns a table of new events which have occurred.                   


   Lower level functions (not for normal use):

   Use these to manage step hooks. Setting =pre_step_hook= and
   =post_step_hook= directly is not permitted anymore:

     *Function*                               *Description*                                                      
    ----------------------------------------+-------------------------------------------------------------------
     =pre_step_hook_add(fsm, hook, where)=    install function hook to be called _before_ each rfsm step of fsm  
     =post_step_hook_add(fsm, hook, where)=   install function hook to be called _after_ each rfsm step of fsm   

   =idle_hook(fsm)=: if defined, called *instead* of returning from
   step/run functions. Used only for debugging purposes.

10 Contact 
-----------

  Please direct questions, bugs or improvements to the [orocos-users]
  mailing list.


  [orocos-users]: http://lists.mech.kuleuven.be/mailman/listinfo/orocos-users

11 Download 
------------

  The code can be found in [this] git repository.

  A cheatsheet summarizing the DSL is available [here].


  [this]: https://github.com/kmarkus/rFSM
  [here]: https://github.com/kmarkus/rfsm-cheatsheet/raw/master/cheatsheet.pdf

12 Acknowledgement 
-------------------

  - Funding

    The research leading to these results has received funding from
    the European Community's Seventh Framework Programme
    (FP7/2007-2013) under grant agreement no. FP7-ICT-231940-BRICS
    (Best Practice in Robotics)

  - Scientific background

    This work borrows many ideas from the Statecharts by David Harel
    and some from UML 2.1 State Machines. The following publications
    are the most relevant

    David Harel and Amnon Naamad. 1996. The STATEMATE semantics of
    statecharts. ACM Trans. Softw. Eng. Methodol. 5, 4 (October 1996),
    293-333. DOI=10.1145/235321.235322
    [http://doi.acm.org/10.1145/235321.235322]

    The OMG UML Specification:
    [http://www.omg.org/spec/UML/2.3/Superstructure/PDF/]


[1] See [this] Real-time Linux Workshop paper, [lua-tlsf] and the
 [minimal Lua real-time POSIX bindings]


[2] The reason for this choice of default is that it fails more
  obviously (100% CPU load) than the opposite (doo function not
  executed properly).

  [this]: https://lwn.net/images/conf/rtlws-2011/paper.05.html
  [lua-tlsf]: https://github.com/kmarkus/lua-tlsf
  [minimal Lua real-time POSIX bindings]: https://github.com/kmarkus/rtp

