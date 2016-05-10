# Fake Makefile that forwards to reggae

REGGAE := reggae/bin/reggae
BUILD_CMD := ./build

include osmodel.mak

ifeq (osx,$(OS))
  BIN:=bin
else
  BIN:=bin$(MODEL)
endif

all: $(BUILD_CMD)
	$(BUILD_CMD) -n

.PHONY: unittest
unittest: $(BUILD_CMD)
	$(BUILD_CMD) -n unittest

.PHONY: html
html: $(BUILD_CMD)
	$(BUILD_CMD) -n html

$(REGGAE): reggae/src/reggae/reggae.d reggae/payload/reggae/backend/binary.d posix.mak
	mkdir -p reggae/bin
	cd reggae && $(MAKE) -f bootstrap.mak

# so that reggae can call dmd when compiling the reggaefile
ifeq (osx,$(OS))
  export SHELL=/bin/bash
endif
export PATH := :$(PATH):$(PWD)/reggae/dmd2/$(OS)/$(BIN)

# remove the .reggae dir because it causes havok with DAutoTest
$(BUILD_CMD): $(REGGAE) reggaefile.d
	$(REGGAE) -b binary -dMODEL=$(MODEL)
	rm -rf .reggae

.PHONY : auto-tester-build
auto-tester-build: $(BUILD_CMD)
	$(BUILD_CMD) -n auto-tester-build

.PHONY : auto-tester-test
auto-tester-test: $(BUILD_CMD)
	$(BUILD_CMD) -n auto-tester-test


install :
	$(BUILD_CMD) -n install
