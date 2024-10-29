luamod_prefix=/usr/share/lua

default:
	@echo "run make install to install Lua modules"

clean:
	rm -f *~

install:
	@install -d -m 755 ${DESTDIR}/${luamod_prefix}/5.1
	@install -d -m 755 ${DESTDIR}/${luamod_prefix}/5.2
	@install -d -m 755 ${DESTDIR}/${luamod_prefix}/5.3
	@install -d -m 755 ${DESTDIR}/${luamod_prefix}/5.4

	@cp -r rfsm/ ${DESTDIR}/${luamod_prefix}/5.1/

	@ln -srf ${DESTDIR}/${luamod_prefix}/5.1/rfsm ${DESTDIR}/${luamod_prefix}/5.2/
	@ln -srf ${DESTDIR}/${luamod_prefix}/5.1/rfsm ${DESTDIR}/${luamod_prefix}/5.3/
	@ln -srf ${DESTDIR}/${luamod_prefix}/5.1/rfsm ${DESTDIR}/${luamod_prefix}/5.4/

uninstall:
	@rm -f ${DESTDIR}/${luamod_prefix}/5.1/rfsm/*
	@rmdir ${DESTDIR}/${luamod_prefix}/5.1/rfsm
	@rm -f ${DESTDIR}/${luamod_prefix}/*/rfsm


PHONY: install uninstall clean
