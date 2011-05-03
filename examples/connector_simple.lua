return rfsm.csta{

   start = rfsm.sista{},
   conn = rfsm.conn{},

   -- specifying 'end' this way is necessary because 'end' is a
   -- reserved keyword in Lua.
   ['end'] = rfsm.sista{},

   rfsm.trans{ src='initial', tgt='start' },
   rfsm.trans{ src='start', tgt='conn', events={"eventA" } },
   rfsm.trans{ src='conn', tgt='end', events={"eventB" } },
}
