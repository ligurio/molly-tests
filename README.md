## Molly tests

[![Static analysis](https://github.com/ligurio/molly-tests/actions/workflows/check.yaml/badge.svg)](https://github.com/ligurio/molly-tests/actions/workflows/check.yaml)

tests based on [Molly](https://github.com/ligurio/molly) library.

```sh
$ git clone https://github.com/ligurio/molly-tests
$ cd molly-tests
$ tt rocks install --server=https://luarocks.org/dev molly
$ tt rocks install luatest
$ PATH=$PATH:$(tt rocks config deploy_bin_dir)
$ luatest -v tarantool.tarantool
Tarantool version is 2.11.3-0-gf933f77904
Running with --shuffle group:1213
Started on Sun Jul  7 19:09:37 2024
    tarantool.tarantool.test_cas_register ... (0.220s) Ok
    tarantool.tarantool.test_bank ... (0.218s) Ok
=========================================================
Ran 2 tests in 0.440 seconds, 2 succeeded, 0 failed
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
