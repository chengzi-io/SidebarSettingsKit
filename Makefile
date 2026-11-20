SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
# ci lists its steps in order; make -j would run test against the previous build.
.NOTPARALLEL:

SWIFT_FLAGS := -Xswiftc -warnings-as-errors
DEMO_DIR := Examples/SidebarSettingsDemo

.PHONY: help
help: ## List targets
	@awk '/^[a-z-]+:.*## / { target = $$0; sub(/:.*/, "", target); split($$0, parts, "## "); printf "  %-12s %s\n", target, parts[2] }' $(MAKEFILE_LIST)

.PHONY: build
build: ## Build the package
	swift build $(SWIFT_FLAGS)

.PHONY: test
test: ## Run the package tests
	swift test $(SWIFT_FLAGS)

.PHONY: demo
# --build-system native: see scripts/screenshots.sh.
demo: ## Run the example app
	cd $(DEMO_DIR) && swift run --build-system native SidebarSettingsDemo

.PHONY: demo-build
demo-build: ## Build the example app
	cd $(DEMO_DIR) && swift build $(SWIFT_FLAGS)

.PHONY: screenshots
screenshots: ## Capture the settings window screenshots into screenshots/
	scripts/screenshots.sh screenshots

.PHONY: ci
ci: build test demo-build ## What CI runs: build, then test, then demo-build

.PHONY: clean
clean: ## Remove build output
	rm -rf .build $(DEMO_DIR)/.build
