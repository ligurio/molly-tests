# This way everything works as expected ever for
# `make -C /path/to/project` or
# `make -f /path/to/project/Makefile`.
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_DIR := $(patsubst %/,%,$(dir $(MAKEFILE_PATH)))
ROCKS_BIN_DIR := $(shell tt rocks config deploy_bin_dir)

all: test

deps:
	@tt rocks install luacheck 0.25.0 --server=https://rocks.tarantool.org/
	@tt rocks install luatest --server=https://rocks.tarantool.org/
	@tt rocks install https://raw.githubusercontent.com/ligurio/molly/dev/molly-scm-1.rockspec

check: luacheck

luacheck:
	@${ROCKS_BIN_DIR}/luacheck --config ${PROJECT_DIR}/.luacheckrc --codes ${PROJECT_DIR}

test:
	@${ROCKS_BIN_DIR}/luatest --verbose -c ${PROJECT_DIR}/test/

clean:
	@rm -f ${CLEANUP_FILES}

.PHONY: luacheck check deps clean test
