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

# sqlite3 CLI for the reset targets: from PATH, else from the Nix dev shell.
ifeq ($(shell command -v sqlite3 2>/dev/null),)
  SQLITE := nix develop -c sqlite3
else
  SQLITE := sqlite3
endif

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
gen: ## drift codegen (`dart run` fails in the Nix shell)
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
	tail -F "$(CACHE_DIR)/logs/kanaru.log"

.PHONY: reset-covers
reset-covers: ## Drop cover thumbnails; the next rescan reads them again
	command rm -rf "$(CACHE_DIR)/covers"

.PHONY: reset-library
reset-library: ## Forget scanned folders and tracks (keeps playlists and listen history), drop covers
	@db="$(DATA_DIR)/library.db"; \
	if [ ! -f "$$db" ]; then echo "No library database at $$db: nothing to reset."; exit 0; fi; \
	pat="$$(realpath "$$db" | sed 's/[][*?\\]/\\&/g')"; \
	if [ -n "$$(find /proc/[0-9]*/fd -lname "$$pat" 2>/dev/null | head -n 1)" ]; then \
	  echo "Kanaru (or another process) has $$db open. Quit it first." >&2; exit 1; fi; \
	$(SQLITE) -bail "$$db" < "$(CURDIR)/packaging/dev/reset-library.sql" \
	  && command rm -rf "$(CACHE_DIR)/covers" \
	  && echo "Library cleared. Playlists and listen history kept; next start opens the empty library (add folders in Settings > Library)."

.PHONY: reset-all
reset-all: ## Like a fresh install: library, playlists, listen history, settings, session, covers, logs
	command rm -rf "$(DATA_DIR)" "$(CONFIG_DIR)" "$(CACHE_DIR)"

##@ Package

# Version for packages: pubspec `version:` without the `+build` suffix.
APP_VERSION := $(shell sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml)
DIST_DIR    := dist

.PHONY: appimage
appimage: ## x86_64 AppImage in dist/, built in Docker (Debian 12); needs network
	@command -v docker >/dev/null || { echo "make appimage needs Docker 23+ (BuildKit)." >&2; exit 1; }
	@test -n "$(APP_VERSION)" || { echo "No version in pubspec.yaml; run make from the repo root." >&2; exit 1; }
	epoch=$$(git log -1 --format=%ct) && docker build --file packaging/appimage/Dockerfile \
	  --build-arg KANARU_VERSION=$(APP_VERSION) \
	  --build-arg BUILD_EPOCH=$$epoch \
	  --target export --output type=local,dest=$(DIST_DIR) .
	@printf '*\n' > $(DIST_DIR)/.gitignore
	@ls -lh $(DIST_DIR)/Kanaru-$(APP_VERSION)-x86_64.AppImage

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
