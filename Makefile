SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
CRUISE_CONTROL_VERSION := 2.5.113
CRUISE_CONTROL_UI_GIT_REF := b1208a6f020c21ff967297814c2e893eed3f3183

##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: build
build: ## Build Cruise Control container image
	@docker build \
		--build-arg "CRUISE_CONTROL_VERSION=$(CRUISE_CONTROL_VERSION)" \
		--build-arg "CRUISE_CONTROL_UI_GIT_REF=$(CRUISE_CONTROL_UI_GIT_REF)" \
		-t ghcr.io/banzaicloud/cruise-control:$(CRUISE_CONTROL_VERSION) \
		.


