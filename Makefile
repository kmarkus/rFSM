luamod_prefix=/usr/share/lua
LUA_VERSIONS=5.1 5.2 5.3 5.4 5.5

default:
	@echo "run make install to install Lua modules, make test to run the tests"

clean:
	rm -f *~ src/rfsm/*~ examples/*~ tests/*~ luac.out src/rfsm/luac.out

test:
	@cd tests && ./run.lua

install:
	@install -d -m 755 $(addprefix ${DESTDIR}/${luamod_prefix}/,${LUA_VERSIONS})
	@cp -r src/rfsm/ ${DESTDIR}/${luamod_prefix}/5.1/
	@for v in 5.2 5.3 5.4 5.5; do \
		ln -srf ${DESTDIR}/${luamod_prefix}/5.1/rfsm ${DESTDIR}/${luamod_prefix}/$$v/ ; \
	done

uninstall:
	@rm -f ${DESTDIR}/${luamod_prefix}/5.1/rfsm/*
	@rmdir ${DESTDIR}/${luamod_prefix}/5.1/rfsm
	@rm -f ${DESTDIR}/${luamod_prefix}/*/rfsm

.PHONY: default install uninstall clean test
