return  rfsm.csta:new{

   start = rfsm.sista:new{},
   conn = rfsm.conn:new{},
   
   -- specifying 'end' this way is necessary because 'end' is a
   -- reserved keyword in Lua.
   ['end'] = rfsm.sista:new{},

   rfsm.trans:new{ src='initial', tgt='start' },
   rfsm.trans:new{ src='start', tgt='conn', events={"eventA" } },
   rfsm.trans:new{ src='conn', tgt='end', events={"eventB" } },
}
