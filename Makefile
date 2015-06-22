SHELL := /bin/bash -euo pipefail
export PATH := go/bin:node_modules/.bin:$(V23_ROOT)/release/go/bin:$(V23_ROOT)/roadmap/go/bin:$(V23_ROOT)/third_party/cout/node/bin:$(PATH)

define BROWSERIFY
	mkdir -p $(dir $2)
	browserify $1 -d -o $2
endef

define BROWSERIFY_MIN
	mkdir -p $(dir $2)
	browserify $1 -d -p [minifyify --map $(notdir $2).map --output $2.map] -o $2
endef

.DELETE_ON_ERROR:

go/bin: $(shell find $(V23_ROOT) -name "*.go")
	v23 go build -a -o $@/principal v.io/x/ref/cmd/principal
	v23 go build -a -tags wspr -o $@/servicerunner v.io/x/ref/cmd/servicerunner
	v23 go build -a -o $@/syncbased v.io/syncbase/x/ref/services/syncbase/syncbased

node_modules: package.json
	npm prune
	npm install
	touch $@
# Link the vanadium and syncbase modules from V23_ROOT.
	rm -rf ./node_modules/{vanadium,syncbase}
	cd "$(V23_ROOT)/release/javascript/core" && npm link
	npm link vanadium
	cd "$(V23_ROOT)/roadmap/javascript/syncbase" && npm link
	npm link syncbase
	touch node_modules

public/bundle.min.js: browser/index.js $(shell find browser) node_modules
ifdef DEBUG
	$(call BROWSERIFY,$<,$@)
else
	$(call BROWSERIFY_MIN,$<,$@)
endif

.PHONY: build
build: go/bin node_modules public/bundle.min.js

.PHONY: serve
serve: export PATH := test:$(PATH)
serve: build
	node ./node_modules/vanadium/test/integration/runner.js --services=start-syncbased.sh -- \
	npm start

.PHONY: clean
clean:
	rm -rf go/bin node_modules public/bundle.min.js

.PHONY: lint
lint:
	jshint .
