--- Helpers for integration tests.
-- This module extends `luatest.helpers` with additional helpers.
--
-- @module test.test-helpers
-- @alias helpers

local luatest = require('luatest')

local helpers = table.copy(luatest.helpers)

return helpers
