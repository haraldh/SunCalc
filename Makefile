include properties.mk

SUPPORTED_DEVICES_LIST = $(shell sed -n -e 's/<iq:product id="\(.*\)"\/>/\1/p' manifest.xml)
SOURCES = $(shell find source -name '[^.]*.mc')
RESFILES = $(shell find resources* -name '[^.]*.xml')
APPNAME = $(shell grep entry manifest.xml | sed 's/.*entry="\([^"]*\).*/\1/' | sed 's/App$$//')
SIMULATOR = LD_LIBRARY_PATH="$(SDK_HOME)/bin" "$(SDK_HOME)/bin/connectiq"
MONKEYC = "$(SDK_HOME)/bin/monkeyc"
MONKEYDO = "$(SDK_HOME)/bin/monkeydo"

.PHONY: all build buildall deploy run test sim simcheck package clean printdevices printsupported

all: build

clean:
	@rm -fr bin
	@find . -name '*~' -print0 | xargs -0 rm -f

build: bin/$(APPNAME)-$(DEVICE).prg

buildall: $(foreach device,$(SUPPORTED_DEVICES_LIST),bin/$(APPNAME)-$(device).prg)

# monkeyc drops scratch files with fixed names (internal-mir/, external-mir/,
# gen/) into the --output directory, so concurrent compiles sharing bin/
# corrupt each other. Each target therefore builds in its own work dir and
# the artifacts are moved into place afterwards — this is what makes
# `make -j buildall` safe.
bin/$(APPNAME)-%.prg: $(SOURCES) $(RESFILES) manifest.xml
	@mkdir -p bin/work/$(@F)
	$(MONKEYC) --warn --output bin/work/$(@F)/$(@F) \
	-f monkey.jungle \
	-y $(PRIVATE_KEY) \
	-d $*
	@mv bin/work/$(@F)/$(@F) $@
	-@mv bin/work/$(@F)/$(@F).debug.xml bin/ 2>/dev/null
	@rm -rf bin/work/$(@F)

bin/$(APPNAME)-$(DEVICE)-test.prg: $(SOURCES) $(RESFILES) manifest.xml
	@mkdir -p bin/work/$(@F)
	$(MONKEYC) --warn --output bin/work/$(@F)/$(@F) \
	-f monkey.jungle \
	-y $(PRIVATE_KEY) \
	--unit-test \
	-d $(DEVICE)
	@mv bin/work/$(@F)/$(@F) $@
	-@mv bin/work/$(@F)/$(@F).debug.xml bin/ 2>/dev/null
	@rm -rf bin/work/$(@F)

sim:
	@pgrep -f "$(SDK_HOME)/bin/simulator" >/dev/null 2>&1 || ( $(SIMULATOR) & sleep 3 )

run: sim bin/$(APPNAME)-$(DEVICE).prg
	$(MONKEYDO) bin/$(APPNAME)-$(DEVICE).prg $(DEVICE) &

# monkeydo exits nonzero even when all tests pass, so grade the run by its
# output instead
test: sim bin/$(APPNAME)-$(DEVICE)-test.prg
	$(MONKEYDO) bin/$(APPNAME)-$(DEVICE)-test.prg $(DEVICE) -t | tee bin/test-output.log
	@grep -q "^PASSED" bin/test-output.log

# Headless smoke test: boot the compiled app in the simulator (under the
# monkey-run FHS sandbox), confirm it loads/runs on $(DEVICE), and save a
# screenshot to bin/simcheck-$(DEVICE)/$(DEVICE).png. Needs the devShell's
# ciq-simcheck: run as `nix develop -c make simcheck DEVICE=...`.
simcheck: bin/$(APPNAME)-$(DEVICE).prg
	ciq-simcheck bin/$(APPNAME)-$(DEVICE).prg $(DEVICE) bin/simcheck-$(DEVICE)

$(DEPLOY)/$(APPNAME).prg: bin/$(APPNAME)-$(DEVICE).prg
	@cp bin/$(APPNAME)-$(DEVICE).prg $(DEPLOY)/$(APPNAME).prg

deploy: build $(DEPLOY)/$(APPNAME).prg

package:
	$(MONKEYC) --warn -e --output bin/$(APPNAME).iq \
	-f monkey.jungle \
	-y $(PRIVATE_KEY) -r

printdevices:
	@printf "%s\n" $(SUPPORTED_DEVICES_LIST)

printsupported:
	@for dev in $$( \
		for i in \
			resources-rectangle-148x205 \
			resources-rectangle-205x148 \
			resources-round-218x218 \
			resources-round-240x240 \
			resources-semiround-215x180 \
			; do \
			grep $${i#resources-} $(SDK_HOME)/bin/devices.xml; \
		done | sed -n -e 's/.*id="\([^"]*\)".*/\1/p' | sort); do \
		echo "      <iq:product id=\"$$dev\"/>"; \
	done
