# rFSM test-suite

The tests use [luaunit](https://github.com/bluebird75/luaunit).

## Running

```sh
./run.lua                 # run the whole suite
./run.lua -v              # verbose
./run.lua TestCore        # a single test class
./test-all-versions.sh    # run against lua5.1 … lua5.5 and luajit
```

or, from the project root:

```sh
make test
```

## Dependencies

- [`luaunit`](https://github.com/bluebird75/luaunit)
- [`uutils`](https://github.com/kmarkus/uutils) (the only rFSM runtime dependency)
- `ansicolors` (used by `rfsm.pp`)

Interpreters that lack these are skipped by `test-all-versions.sh`.

## Layout

| File                  | Covers                                                  |
|-----------------------|---------------------------------------------------------|
| `common.lua`          | shared helpers (`init`, `fqn`, `mode`, `send_run`, …)   |
| `test_core.lua`       | states, transitions, guards, effects, priorities, reset |
| `test_connector.lua`  | connectors / compound transitions                       |
| `test_composite.lua`  | nested composites, re-entry, example models             |
| `test_doo.lua`        | `doo` coroutines, completion events, idle flag          |
| `test_extensions.lua` | `emem`, `await`, `checkevents`, monitor state, seqand   |
| `test_timeevent.lua`  | time events (virtual clock)                             |
| `test_marsh.lua`      | marshalling (`rfsm.marsh`, `rfsm.rfsm2json`)            |
