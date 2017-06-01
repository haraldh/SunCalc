include properties.mk

SUPPORTED_DEVICES_LIST = $(shell sed -n -e 's/<iq:product id="\(.*\)"\/>/\1/p' manifest.xml)

sources = $(shell find source -name '[^.]*.mc')
resources = $(shell find resources* -name '[^.]*.xml' | tr '\n' ':' | sed 's/.$$//')
resfiles = $(shell find resources* -name '[^.]*.xml')
appName = $(shell grep entry manifest.xml | sed 's/.*entry="\([^"]*\).*/\1/' | sed 's/App$$//')
SIMULATOR = $(shell [ "$$(uname)" == "Linux" ] && echo "wine32 $(SDK_HOME)/bin/simulator.exe" || echo '$(SDK_HOME)/bin/connectiq')
MONKEYC = java -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true -jar $(SDK_HOME)/bin/monkeybrains.jar

.PHONY: build deploy buildall run package clean

all: build

clean:
	@rm -fr bin
	@find . -name '*~' -print0 | xargs -0 rm -f 

build: bin/$(appName)-$(DEVICE).prg

bin/$(appName)-$(DEVICE).prg: $(sources) $(resfiles)
	$(MONKEYC) --warn --output bin/$(appName)-$(DEVICE).prg -m manifest.xml \
	-z $(resources) \
	-y $(PRIVATE_KEY) \
	-d $(DEVICE) $(sources)

bin/$(appName)-$(DEVICE)-test.prg: $(sources) $(resfiles)
	$(MONKEYC) --warn --output bin/$(appName)-$(DEVICE)-test.prg -m manifest.xml \
	-z $(resources) \
	-y $(PRIVATE_KEY) \
	--unit-test \
	-d $(DEVICE) $(sources)

buildall:
	@for device in $(SUPPORTED_DEVICES_LIST); do \
		echo "-----"; \
		echo "Building for" $$device; \
    $(MONKEYC)  --warn --output bin/$(appName)-$$device.prg -m manifest.xml \
    -z $(resources) \
    -y $(PRIVATE_KEY) \
    -d $$device $(sources); \
	done

sim:
	$(SIMULATOR) &

run: bin/$(appName)-$(DEVICE).prg
	$(SDK_HOME)/bin/monkeydo bin/$(appName)-$(DEVICE).prg $(DEVICE) &

test: bin/$(appName)-$(DEVICE)-test.prg
	$(SDK_HOME)/bin/monkeydo bin/$(appName)-$(DEVICE)-test.prg $(DEVICE) -t

$(DEPLOY)/$(appName).prg: bin/$(appName)-$(DEVICE).prg
	@cp bin/$(appName)-$(DEVICE).prg $(DEPLOY)/$(appName).prg

deploy: build $(DEPLOY)/$(appName).prg

package:
	@$(MONKEYC) --warn -e --output bin/$(appName).iq -m manifest.xml \
	-z $(resources) \
	-y $(PRIVATE_KEY) \
	$(sources) -r
