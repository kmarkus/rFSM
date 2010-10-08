return  rfsm.csta:new{

   start = rfsm.sista:new{},
   junc = rfsm.junc:new{},
   
   -- specifying 'end' this way is necessary because 'end' is a
   -- reserved keyword in Lua.
   ['end'] = rfsm.sista:new{},

   rfsm.trans:new{ src='initial', tgt='start' },
   rfsm.trans:new{ src='start', tgt='junc', events={"eventA" } },
   rfsm.trans:new{ src='junc', tgt='end', events={"eventB" } },
}
