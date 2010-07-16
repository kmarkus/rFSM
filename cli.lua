require("fsmdbg")

c = assert(fsmdbg.cli:new("localhost"))
c:sendev("e_on")
