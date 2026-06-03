#!/usr/bin/env lua
--
-- rFSM test-suite runner.
--
-- Run all tests:        ./run.lua
-- Run with options:     ./run.lua -v        (verbose)
--                       ./run.lua -o junit  (junit xml output)
-- Run a single class:   ./run.lua TestCore
--
-- SPDX-License-Identifier: BSD-3-Clause

-- make the in-tree modules and the test helpers loadable regardless of
-- the current working directory or whether rfsm is installed.
local sep = package.config:sub(1,1)
local here = (arg[0]:match("^(.*)" .. sep) or ".") .. sep
package.path = here .. "../src/?.lua;" ..
               here .. "../src/?/init.lua;" ..
               here .. "?.lua;" .. package.path

local lu = require("luaunit")

-- collect the test classes (each module sets a global Test* table)
TestCore       = require("test_core")
TestConnector  = require("test_connector")
TestComposite  = require("test_composite")
TestDoo        = require("test_doo")
TestExtensions = require("test_extensions")
TestTimeevent  = require("test_timeevent")
TestMarsh      = require("test_marsh")

os.exit(lu.LuaUnit.run())
