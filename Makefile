SHELL := /bin/bash -euo pipefail

# Add $JIRI_ROOT/devtools/bin to PATH (for the jiri tool) in case the user
# hasn't done so in their ~/.bashrc.
export PATH := $(JIRI_ROOT)/devtools/bin:$(PATH)

# Add a few more things to PATH.
NODE_DIR := $(shell jiri v23-profile list --info Target.InstallationDir nodejs)
export PATH := node_modules/.bin:$(JIRI_ROOT)/release/go/bin:$(NODE_DIR)/bin:$(PATH)

# Default browserify options: use sourcemaps.
BROWSERIFY_OPTS := --debug
# Names that should not be mangled by minification.
RESERVED_NAMES := 'context,ctx,callback,cb,$$stream,serverCall'
# Don't mangle RESERVED_NAMES, and screw ie8.
MANGLE_OPTS := --mangle [ --except $(RESERVED_NAMES) --screw_ie8 ]
# Don't remove unused variables from function arguments, which could mess up
# signatures. Also don't evaulate constant expressions, since we rely on them to
# conditionally require modules only in node.
COMPRESS_OPTS := --compress [ --no-unused --no-evaluate ]
# Workaround for Browserify opening too many files: increase the limit on file
# descriptors.
# https://github.com/substack/node-browserify/issues/431
INCREASE_FILE_DESC := ulimit -S -n 2560

# If NOFIND is set, assume that files under JIRI_ROOT are static. This reduces
# build time dramatically.
ifdef NOFIND
	FIND := true
else
	FIND := find
endif

# Browserify and extract sourcemap, but do not minify.
define BROWSERIFY
	mkdir -p $(dir $2)
	$(INCREASE_FILE_DESC); \
	browserify $1 $(BROWSERIFY_OPTS) | exorcist $2.map > $2
endef

# Browserify, minify, and extract sourcemap.
define BROWSERIFY_MIN
	mkdir -p $(dir $2)
	$(INCREASE_FILE_DESC); \
	browserify $1 $(BROWSERIFY_OPTS) --g [ uglifyify $(MANGLE_OPTS) $(COMPRESS_OPTS) ] | exorcist $2.map > $2
endef

.DELETE_ON_ERROR:

# Builds mounttabled, principal, and syncbased.
bin: $(shell $(FIND) $(JIRI_ROOT) -name "*.go") | env-check
	jiri go build -a -o $@/mounttabled v.io/x/ref/services/mounttable/mounttabled
	jiri go build -a -o $@/principal v.io/x/ref/cmd/principal
	jiri go build -a -o $@/syncbased v.io/x/ref/services/syncbase/syncbased
	touch $@

# Mints credentials.
creds: bin
	./bin/principal seekblessings --v23.credentials creds
	touch $@

node_modules: package.json $(shell $(FIND) $(JIRI_ROOT)/release/javascript/syncbase/{package.json,src} $(JIRI_ROOT)/release/javascript/core/{package.json,src}) | env-check
	npm prune
	npm install
# Link the vanadium and syncbase modules from JIRI_ROOT.
	rm -rf ./node_modules/{vanadium,syncbase}
	cd "$(JIRI_ROOT)/release/javascript/core" && npm link
	npm link vanadium
# Note, we run "make node_modules" in the JS syncbase repo to ensure that the
# vanadium module is linked there.
	cd "$(JIRI_ROOT)/release/javascript/syncbase" && make node_modules && npm link
	npm link syncbase
# Note, browserify 10.2.5 and up will share the vanadium module instance between
# todosapp and syncbase, since their node_modules symlinks point to a common
# location.
# https://github.com/substack/node-browserify/issues/1063
	touch $@

# TODO(sadovsky): Newest cssnano appears to be broken with Vanadium's old
# version of node, 0.10.24.
public/bundle.min.css: $(shell find stylesheets) node_modules
# lessc -sm=on stylesheets/index.less | postcss -u autoprefixer -u cssnano > $@
	lessc -sm=on stylesheets/index.less | postcss -u autoprefixer > $@

public/bundle.min.js: browser/index.js $(shell find browser) node_modules
ifdef DEBUG
	$(call BROWSERIFY,$<,$@)
else
	$(call BROWSERIFY_MIN,$<,$@)
endif

.PHONY: build
build: bin node_modules public/bundle.min.css public/bundle.min.js

.PHONY: serve
serve: build
	npm start

.PHONY: env-check
env-check:
ifndef JIRI_ROOT
	$(error JIRI_ROOT is not set.  Please install Vanadium per the contributor instructions)
endif

.PHONY: clean
clean:
	rm -rf bin node_modules public/bundle.*
	jiri goext distclean

.PHONY: lint
lint: node_modules
	jshint .
