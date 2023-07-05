SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

CI ?= false
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
CRUISE_CONTROL_VERSION ?= 2.5.123
CRUISE_CONTROL_UI_GIT_REF ?= b1208a6f020c21ff967297814c2e893eed3f3183
DOCKER_COMPOSE_PROJECT_NAME := "docker-cruise-control"
DOCKER_COMPOSE_PROJECT_DIR := "./deploy"
DOCKER_COMPOSE_TIMEOUT := 120
GIT_SHA := $(shell git rev-parse  HEAD)
GIT_SHA_SHORT := $(shell git rev-parse --short HEAD)
GIT_REF := $(shell git describe --dirty --always)

export CRUISE_CONTROL_IMAGE ?= "ghcr.io/banzaicloud/cruise-control:$(GIT_SHA_SHORT)"

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
		--tag $(CRUISE_CONTROL_IMAGE) \
		--label "org.opencontainers.image.version=$(CRUISE_CONTROL_VERSION)" \
		--label "org.opencontainers.image.revision=$(GIT_SHA)" \
		--label "org.opencontainers.image.ref.name=$(GIT_REF)" \
		.

.PHONY: start
start: ## Start test environment
	@docker compose \
		--project-name "$(DOCKER_COMPOSE_PROJECT_NAME)" \
		--project-directory "$(DOCKER_COMPOSE_PROJECT_DIR)" \
		up -d \
		--remove-orphans \
		--timeout "$(DOCKER_COMPOSE_TIMEOUT)" \
		--wait

.PHONY: stop
stop: ## Stop test environment
	@docker compose \
		--project-name "$(DOCKER_COMPOSE_PROJECT_NAME)" \
		--project-directory "$(DOCKER_COMPOSE_PROJECT_DIR)" \
		down \
		--remove-orphans \
		--volumes \
		--timeout "$(DOCKER_COMPOSE_TIMEOUT)"

.PHONY: test
test: ## Run tests
	@./test.sh

## Skip building container image in CI
ifeq ($(CI),true)
test:
else
test: build
endif

##@ CI

.PHONY: cruise-control-version
cruise-control-version: ## Print Cruise Control version
	@printf 'version=%s\n' "$(CRUISE_CONTROL_VERSION)"

.PHONY: cruise-control-version
cruise-control-ui-version: ## Print Cruise Control UI version
	@printf 'version=%s\n' "$(CRUISE_CONTROL_UI_GIT_REF)"
