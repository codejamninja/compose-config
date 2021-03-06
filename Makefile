PLATFORM := $(shell node -e "process.stdout.write(process.platform)")
ifeq ($(PLATFORM), win32)
  SHELL = cmd
endif

NPM := npm
ifeq ($(shell pnpm --version >/dev/null 2>&1 && echo true || echo false), true)
	NPM = pnpm
else
ifeq ($(shell yarn --version >/dev/null 2>&1 && echo true || echo false), true)
	NPM = yarn
endif
endif

.EXPORT_ALL_VARIABLES:

.PHONY: all
all: build

.PHONY: install
install: node_modules
node_modules: package.json
	@$(NPM) install

.PHONY: prepare
prepare:
	@sh prepare.sh

.PHONY: format
format: install
	@prettier --write ./**/*.{json,md,scss,yaml,yml,js,jsx,ts,tsx} --ignore-path .gitignore
	@mkdir -p node_modules/.make && touch -m node_modules/.make/format
node_modules/.make/format: $(shell git ls-files | grep -P "\.(j|t)sx?$$")
	@$(MAKE) -s format

.PHONY: spellcheck
spellcheck: node_modules/.make/format
	-@cspell --config .cspellrc src/**/*.ts
	@mkdir -p node_modules/.make && touch -m node_modules/.make/spellcheck
node_modules/.make/spellcheck: $(shell git ls-files | grep -P "\.(j|t)sx?$$")
	-@$(MAKE) -s spellcheck

.PHONY: lint
lint: node_modules/.make/spellcheck
	-@tsc --allowJs --noEmit
	-@eslint --fix --ext .ts,.tsx .
	@eslint -f json -o node_modules/.tmp/eslintReport.json --ext .ts,.tsx ./
node_modules/.tmp/eslintReport.json: $(shell git ls-files | grep -P "\.(j|t)sx?$$")
	-@$(MAKE) -s lint

.PHONY: test
test: node_modules/.tmp/eslintReport.json
	@jest --coverage --coverageDirectory node_modules/.tmp/coverage
node_modules/.tmp/coverage/lcov.info: $(shell git ls-files | grep -P "\.(j|t)sx?$$")
	-@$(MAKE) -s test

.PHONY: clean
clean:
	-@jest --clearCache
	@git clean -fXd -e \!/node_modules -e \!/node_modules/**/* -e \!/yarn.lock -e \!/pnpm-lock.yaml -e \!/package-lock.json
	-@rm -rf node_modules/.cache || true
	-@rm -rf node_modules/.make || true
	-@rm -rf node_modules/.tmp || true

.PHONY: build
build: lib
lib: node_modules/.tmp/coverage/lcov.info $(shell git ls-files)
	-@rm -rf lib 2>/dev/null || true
	@babel src -d lib --extensions '.ts,.tsx' --source-maps inline
	@tsc -d --emitDeclarationOnly
	@mv .tmp/lib/src/* lib
	-@rm -rf .tmp/lib 2>/dev/null || true

.PHONY: start
start:
	@babel-node --extensions '.ts,.tsx' example $(ARGS)

.PHONY: purge
purge: clean
	@git clean -fXd

.PHONY: report
report: spellcheck lint test
	@

%:
	@
