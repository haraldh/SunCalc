include properties.mk

SUPPORTED_DEVICES_LIST = $(shell sed -n -e 's/<iq:product id="\(.*\)"\/>/\1/p' manifest.xml)
SOURCES = $(shell find source -name '[^.]*.mc')
RESOURCE_FLAGS = $(shell find resources* -name '[^.]*.xml' | tr '\n' ':' | sed 's/.$$//')
RESFILES = $(shell find resources* -name '[^.]*.xml')
APPNAME = $(shell grep entry manifest.xml | sed 's/.*entry="\([^"]*\).*/\1/' | sed 's/App$$//')
SIMULATOR = $(shell [ "$$(uname)" == "Linux" ] && echo "wine32 $(SDK_HOME)/bin/simulator.exe" || echo '$(SDK_HOME)/bin/connectiq')
MONKEYC = java -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true -jar $(SDK_HOME)/bin/monkeybrains.jar

.PHONY: build deploy buildall run package clean sim

all: build

clean:
	@rm -fr bin
	@find . -name '*~' -print0 | xargs -0 rm -f

build: bin/$(APPNAME)-$(DEVICE).prg

bin/$(APPNAME)-$(DEVICE).prg: $(SOURCES) $(RESFILES)
	$(MONKEYC) --warn --output bin/$(APPNAME)-$(DEVICE).prg \
	-f monkey.jungle \
	-y $(PRIVATE_KEY) \
	-d $(DEVICE)

bin/$(APPNAME)-$(DEVICE)-test.prg: $(SOURCES) $(RESFILES)
	$(MONKEYC) --warn --output bin/$(APPNAME)-$(DEVICE)-test.prg \
	-f monkey.jungle \
	-y $(PRIVATE_KEY) \
	--unit-test \
	-d $(DEVICE)

buildall:
	@for device in $(SUPPORTED_DEVICES_LIST); do \
		echo "-----"; \
		echo "Building for" $$device; \
		$(MONKEYC) --warn --output bin/$(APPNAME)-$$device.prg \
		           -f monkey.jungle \
			   -y $(PRIVATE_KEY) \
                           -d $$device; \
	done

sim:
	@pidof 'simulator.exe' &>/dev/null || ( $(SIMULATOR) & sleep 3 )

run: sim bin/$(APPNAME)-$(DEVICE).prg
	$(SDK_HOME)/bin/monkeydo bin/$(APPNAME)-$(DEVICE).prg $(DEVICE) &

test: sim bin/$(APPNAME)-$(DEVICE)-test.prg
	$(SDK_HOME)/bin/monkeydo bin/$(APPNAME)-$(DEVICE)-test.prg $(DEVICE) -t

$(DEPLOY)/$(APPNAME).prg: bin/$(APPNAME)-$(DEVICE).prg
	@cp bin/$(APPNAME)-$(DEVICE).prg $(DEPLOY)/$(APPNAME).prg

deploy: build $(DEPLOY)/$(APPNAME).prg

package:
	@$(MONKEYC) --warn -e --output bin/$(APPNAME).iq \
	-f monkey.jungle \
	-y $(PRIVATE_KEY) -r
