# Shortcuts for everyday Kanaru work. `make` (or `make help`) lists them.
#
# Commands run inside the Nix dev shell unless `flutter` is already on PATH
# (direnv, or a non-Nix setup from docs/development.md).

SHELL := bash

ifeq ($(shell command -v flutter 2>/dev/null),)
  DEV := nix develop -c
else
  DEV :=
endif

# App folders, as lib/core/paths/app_directories.dart resolves them.
CONFIG_DIR := $(or $(XDG_CONFIG_HOME),$(HOME)/.config)/kanaru
DATA_DIR   := $(or $(XDG_DATA_HOME),$(HOME)/.local/share)/kanaru
CACHE_DIR  := $(or $(XDG_CACHE_HOME),$(HOME)/.cache)/kanaru

.DEFAULT_GOAL := help

##@ Run

.PHONY: get
get: ## Fetch Dart packages
	$(DEV) flutter pub get

.PHONY: run
run: ## Run the app on Linux (debug)
	$(DEV) flutter run -d linux

.PHONY: run-release
run-release: ## Run the app on Linux (release)
	$(DEV) flutter run -d linux --release

.PHONY: build
build: ## Build the Linux release bundle
	$(DEV) flutter build linux --release

##@ Check

.PHONY: analyze
analyze: ## Static analysis
	$(DEV) flutter analyze

.PHONY: format
format: ## Format Dart code
	$(DEV) dart format lib test

.PHONY: test
test: ## Dart tests; narrow with T=path, e.g. make test T=test/core/indexer
	$(DEV) flutter test $(T)

.PHONY: test-rust
test-rust: ## Rust tests
	$(DEV) cargo test --locked --manifest-path rust/Cargo.toml

.PHONY: check
check: analyze test test-rust ## Everything a PR must pass

##@ Generate

.PHONY: gen
gen: ## drift / riverpod codegen (`dart run` fails in the Nix shell)
	$(DEV) flutter pub run build_runner build --delete-conflicting-outputs

.PHONY: gen-rust
gen-rust: ## Rust bridge bindings, after changing rust/src/api
	$(DEV) env RUSTC_BOOTSTRAP=1 flutter_rust_bridge_codegen generate

.PHONY: migrations
migrations: ## New drift migration step, after bumping schemaVersion
	$(DEV) flutter pub run drift_dev make-migrations

##@ App data (quit Kanaru first)

.PHONY: logs
logs: ## Follow the app log
	tail -F $(CACHE_DIR)/logs/kanaru.log

.PHONY: reset-covers
reset-covers: ## Drop cover thumbnails; the next rescan reads them again
	command rm -rf $(CACHE_DIR)/covers

.PHONY: reset-library
reset-library: ## Drop the library database: next start shows the folder picker
	command rm -rf $(DATA_DIR)

.PHONY: reset-all
reset-all: ## Like a fresh install: library, settings, playback session, covers (logs kept)
	command rm -rf $(DATA_DIR) $(CONFIG_DIR) $(CACHE_DIR)/covers

##@ Clean

.PHONY: clean
clean: ## Remove Flutter and Rust build outputs
	$(DEV) flutter clean
	$(DEV) cargo clean --manifest-path rust/Cargo.toml

.PHONY: help
help: ## List the targets
	@awk 'BEGIN {FS = ":.*## "} \
	  /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} \
	  /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' \
	  $(MAKEFILE_LIST)
