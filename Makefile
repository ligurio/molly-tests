# This way everything works as expected ever for
# `make -C /path/to/project` or
# `make -f /path/to/project/Makefile`.
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_DIR := $(patsubst %/,%,$(dir $(MAKEFILE_PATH)))

all: check

deps:
	@tarantoolctl rocks install luacheck 0.25.0
	@tarantoolctl rocks install luatest
	@tarantoolctl rocks install https://raw.githubusercontent.com/ligurio/molly/dev/molly-scm-1.rockspec

check: luacheck

luacheck:
	@luacheck --config $(PROJECT_DIR)/.luacheckrc --codes $(PROJECT_DIR)

clean:
	@rm -f ${CLEANUP_FILES}

.PHONY: luacheck check deps clean
