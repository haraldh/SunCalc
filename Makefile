include properties.mk

FLAGS = -w
SUPPORTED_DEVICES_LIST = $(shell sed -n -e 's/<iq:product id="\(.*\)"\/>/\1/p' manifest.xml)

sources = $(shell find source -name '[^.]*.mc')
resources = $(shell find resources* -name '[^.]*.xml' | tr '\n' ':' | sed 's/.$$//')
resfiles = $(shell find resources* -name '[^.]*.xml')
appName = $(shell grep entry manifest.xml | sed 's/.*entry="\([^"]*\).*/\1/' | sed 's/App$$//')

MONKEYC = java -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true -jar $(SDK_HOME)/bin/monkeybrains.jar

.PHONY: build deploy buildall run package clean

all: build

clean:
	@rm -fr bin
	@find . -name '*~' -print0 | xargs -0 rm -f 

build: bin/$(appName).prg $(resfiles)

bin/$(appName).prg: $(sources)
	$(MONKEYC) $(FLAGS) --warn --output bin/$(appName).prg -m manifest.xml \
	-z $(resources) \
	-y $(PRIVATE_KEY) \
	-d $(DEFAULT_DEVICE) $(sources)

buildall:
	@for device in $(SUPPORTED_DEVICES_LIST); do \
		echo "-----"; \
		echo "Building for" $$device; \
    $(MONKEYC) $(FLAGS) --warn --output bin/$(appName)-$$device.prg -m manifest.xml \
    -z $(resources) \
    -y $(PRIVATE_KEY) \
    -d $$device $(sources); \
	done

run: build
	@$(SDK_HOME)/bin/connectiq &&\
	sleep 3 &&\
	$(SDK_HOME)/bin/monkeydo bin/$(appName).prg $(DEFAULT_DEVICE)

$(DEPLOY)/$(appName).prg: bin/$(appName).prg
	@cp bin/$(appName).prg $(DEPLOY)/$(appName).prg

deploy: build $(DEPLOY)/$(appName).prg

package:
	@$(MONKEYC) $(FLAGS) --warn -e --output bin/$(appName).iq -m manifest.xml \
	-z $(resources) \
	-y $(PRIVATE_KEY) \
	$(sources) -r
