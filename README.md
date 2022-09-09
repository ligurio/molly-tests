## Molly tests

tests based on [Molly](https://github.com/ligurio/molly) library.

```sh
$ git clone https://github.com/ligurio/molly-tests
$ cd ../molly-tests/
$ luarocks --local install --server=https://luarocks.org/dev molly
$ tarantoolctl rocks install luatest
$ PATH=$PATH:$(tarantoolctl rocks config deploy_bin_dir)
$ luatest -v -c test/tarantool/tarantool_test.lua
$ luatest -v -c test/tarantool/qsync_test.lua
$
$ VER=0.1.4
$ curl -O -L https://github.com/ligurio/elle-cli/releases/download/${VER}/elle-cli-bin-${VER}.zip
$ unzip elle-cli-bin-${VER}.zip
$ java -jar ./target/elle-cli-${VER}-standalone.jar -m elle-rw-register history.json
```
