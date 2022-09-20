## Molly tests

tests based on [Molly](https://github.com/ligurio/molly) library.

```sh
$ git clone https://github.com/ligurio/molly-tests
$ cd molly-tests
$ luarocks --local install --server=https://luarocks.org/dev molly
$ tarantoolctl rocks install luatest
$ PATH=$PATH:$(tarantoolctl rocks config deploy_bin_dir)
$ luatest -v tarantool.tarantool.test_cas_register
$
$ sudo apt install default-jre
$ java --version
openjdk 11.0.16 2022-07-19
OpenJDK Runtime Environment (build 11.0.16+8-post-Ubuntu-0ubuntu122.04)
OpenJDK 64-Bit Server VM (build 11.0.16+8-post-Ubuntu-0ubuntu122.04, mixed mode, sharing)
$
$ export VER=0.1.4
$ curl -O -L https://github.com/ligurio/elle-cli/releases/download/${VER}/elle-cli-bin-${VER}.zip
$ unzip elle-cli-bin-${VER}.zip -d elle-cli
$ java -jar ./elle-cli/target/elle-cli-${VER}-standalone.jar -m cas-register history.json
history.json     true
```
