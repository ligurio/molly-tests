## Molly tests

tests based on [Molly](https://github.com/ligurio/molly) library.

```sh
$ git clone https://github.com/ligurio/molly-tests
$ cd ../molly-tests/
$ luarocks --local install --server=https://luarocks.org/dev molly
$ tarantoolctl rocks install luatest
$ ./.rocks/bin/luatest -v -c test/tarantool/tarantool_test.lua
$ ./.rocks/bin/luatest -v -c test/tarantool/qsync_test.lua
```
