--- Helpers for integration testing.
-- This module extends `luatest.helpers` with additional helpers.
--
-- @module topology.test-helpers
-- @alias helpers

local luatest = require('luatest')

local helpers = table.copy(luatest.helpers)

return helpers
