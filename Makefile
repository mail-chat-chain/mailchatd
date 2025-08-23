#!/usr/bin/make -f

###############################################################################
###                           Module & Versioning                           ###
###############################################################################

VERSION ?= $(shell echo $(shell git describe --tags --always) | sed 's/^v//')
TMVERSION := $(shell go list -m github.com/cometbft/cometbft | sed 's:.* ::')
COMMIT := $(shell git log -1 --format='%H')

###############################################################################
###                          Directories & Binaries                         ###
###############################################################################

BINDIR ?= $(GOPATH)/bin
BUILDDIR ?= $(CURDIR)/build
EXAMPLE_BINARY := mailchatd

###############################################################################
###                              Repo Info                                  ###
###############################################################################

HTTPS_GIT := https://github.com/mail-chat-chain/mail-chat-chain.git
DOCKER := $(shell which docker)

export GO111MODULE = on

###############################################################################
###                            Submodule Settings                           ###
###############################################################################

# mailchatd is a separate module under ./cmd/mailchatd
MAILCHATD_DIR      := .
MAILCHATD_MAIN_PKG := ./cmd/mailchatd

###############################################################################
###                        Build & Install mailchatd                        ###
###############################################################################

# process build tags
build_tags = netgo

ifeq (cleveldb,$(findstring cleveldb,$(COSMOS_BUILD_OPTIONS)))
  build_tags += gcc
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

# process linker flags

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=mailchatd \
          -X github.com/cosmos/cosmos-sdk/version.AppName=$(EXAMPLE_BINARY) \
          -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
          -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
          -X github.com/cometbft/cometbft/version.TMCoreSemVer=$(TMVERSION)

# DB backend selection
ifeq (cleveldb,$(findstring cleveldb,$(COSMOS_BUILD_OPTIONS)))
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
endif

# add build tags to linker flags
whitespace := $(subst ,, )
comma := ,
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))
ldflags += -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)"

ifeq (,$(findstring nostrip,$(COSMOS_BUILD_OPTIONS)))
  ldflags += -w -s
endif
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

ifeq (staticlink,$(findstring staticlink,$(COSMOS_BUILD_OPTIONS)))
  ldflags += -linkmode external -extldflags '-static'
endif

BUILD_FLAGS := -tags "$(build_tags)" -ldflags '$(ldflags)'
# check for nostrip option
ifeq (,$(findstring nostrip,$(COSMOS_BUILD_OPTIONS)))
  BUILD_FLAGS += -trimpath
endif

# check if no optimization option is passed
# used for remote debugging
ifneq (,$(findstring nooptimization,$(COSMOS_BUILD_OPTIONS)))
  BUILD_FLAGS += -gcflags "all=-N -l"
endif

# Build into $(BUILDDIR)
build: go.sum $(BUILDDIR)/
	@echo "🏗️  Building mailchatd to $(BUILDDIR)/$(EXAMPLE_BINARY) ..."
	@cd $(MAILCHATD_DIR) && CGO_ENABLED="1" \
	  go build $(BUILD_FLAGS) -o $(BUILDDIR)/$(EXAMPLE_BINARY) $(MAILCHATD_MAIN_PKG)

# Cross-compile for Linux AMD64
build-linux:
	GOOS=linux GOARCH=amd64 $(MAKE) build

# Install into $(BINDIR)
install: go.sum
	@echo "🚚  Installing mailchatd to $(BINDIR) ..."
	@cd $(MAILCHATD_DIR) && CGO_ENABLED="1" \
	  go install $(BUILD_FLAGS) $(MAILCHATD_MAIN_PKG)

$(BUILDDIR)/:
	mkdir -p $(BUILDDIR)/

# Default & all target
.PHONY: all build build-linux install
all: build

###############################################################################
###                          Tools & Dependencies                           ###
###############################################################################

go.sum: go.mod
	echo "Ensure dependencies have not been modified ..." >&2
	go mod verify
	go mod tidy

vulncheck:
	@go install golang.org/x/vuln/cmd/govulncheck@latest
	@govulncheck ./...

###############################################################################
###                           Tests & Simulation                            ###
###############################################################################

PACKAGES_NOSIMULATION=$(shell go list ./... | grep -v '/simulation')
PACKAGES_UNIT := $(shell go list ./... | grep -v '/tests/e2e$$' | grep -v '/simulation')
# PACKAGES_EVMD := $(shell cd evmd && go list ./... | grep -v '/simulation') # evmd not available in this project
COVERPKG_ALL := $(shell go list ./... | grep -v '/tests/e2e$$' | grep -v '/simulation' | paste -sd, -)
COMMON_COVER_ARGS := -timeout=15m -covermode=atomic

TEST_PACKAGES := ./...
TEST_TARGETS := test-unit test-unit-cover test-race

test-unit: ARGS=-timeout=15m
test-unit: TEST_PACKAGES=$(PACKAGES_UNIT)
test-unit: run-tests

test-race: ARGS=-race
test-race: TEST_PACKAGES=$(PACKAGES_UNIT)
test-race: run-tests

# test-evmd: ARGS=-timeout=15m
# test-evmd:
#	@cd evmd && go test -tags=test -mod=readonly $(ARGS) $(EXTRA_ARGS) $(PACKAGES_EVMD)
# evmd tests removed as evmd directory doesn't exist in this project

test-unit-cover: ARGS=-timeout=15m -coverprofile=coverage.txt -covermode=atomic
test-unit-cover: TEST_PACKAGES=$(PACKAGES_UNIT)
test-unit-cover: run-tests
	@echo "🔍 Running coverage..."
	@go test -tags=test $(COMMON_COVER_ARGS) -coverpkg=$(COVERPKG_ALL) -coverprofile=coverage.txt ./...
	@echo "🧹 Filtering ignored files from coverage.txt..."
	@grep -v -E '/cmd/|/client/|/proto/|/testutil/|/mocks/|/test_.*\.go:|\.pb\.go:|\.pb\.gw\.go:|/x/[^/]+/module\.go:|/scripts/|/ibc/testing/|/version/|\.md:|\.pulsar\.go:' coverage.txt > tmp_coverage.txt && mv tmp_coverage.txt coverage.txt
	@echo "📊 Coverage summary:"
	@go tool cover -func=coverage.txt

test: test-unit

test-all:
	@echo "🔍 Running all module tests..."
	@go test -tags=test -mod=readonly -timeout=15m $(PACKAGES_NOSIMULATION)

run-tests:
ifneq (,$(shell which tparse 2>/dev/null))
	go test -tags=test -mod=readonly -json $(ARGS) $(EXTRA_ARGS) $(TEST_PACKAGES) | tparse
else
	go test -tags=test -mod=readonly $(ARGS) $(EXTRA_ARGS) $(TEST_PACKAGES)
endif

# test-fuzz removed - x/precisebank module does not exist in this project

# test-scripts removed - scripts directory does not exist in this project

# test-solidity removed - script does not exist in this project

.PHONY: run-tests test test-all $(TEST_TARGETS)

benchmark:
	@go test -tags=test -mod=readonly -bench=. $(PACKAGES_NOSIMULATION)

.PHONY: benchmark

###############################################################################
###                                Linting                                  ###
###############################################################################
golangci_lint_cmd=golangci-lint
golangci_version=v2.2.2

lint: lint-go

lint-go:
	@echo "--> Running linter"
	@go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(golangci_version)
	@$(golangci_lint_cmd) run --timeout=15m

# lint-python removed - no Python files in this project

# lint-contracts removed - contracts directory does not exist

lint-fix:
	@go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(golangci_version)
	@$(golangci_lint_cmd) run --timeout=15m --fix

# lint-fix-contracts removed - contracts directory does not exist

.PHONY: lint lint-fix lint-contracts lint-go lint-python

format: format-go format-shell

format-go:
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -path "./client/docs/statik/statik.go" -not -name '*.pb.go' -not -name '*.pb.gw.go' -not -name '*.pulsar.go' | xargs gofumpt -w -l

# format-python, format-black, format-isort removed - no Python files in this project

format-shell:
	shfmt -l -w .

.PHONY: format format-go format-shell

# Protobuf functionality removed - proto directory does not exist in this project

###############################################################################
###                                Releasing                                ###
###############################################################################

PACKAGE_NAME:=github.com/mail-chat-chain/mailchatd
GOLANG_CROSS_VERSION  = v1.22
GOPATH ?= '$(HOME)/go'
release-dry-run:
	docker run \
		--rm \
		--privileged \
		-e CGO_ENABLED=1 \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v `pwd`:/go/src/$(PACKAGE_NAME) \
		-v ${GOPATH}/pkg:/go/pkg \
		-w /go/src/$(PACKAGE_NAME) \
		ghcr.io/goreleaser/goreleaser-cross:${GOLANG_CROSS_VERSION} \
		--clean --skip validate --skip publish --snapshot

release:
	@if [ ! -f ".release-env" ]; then \
		echo "\033[91m.release-env is required for release\033[0m";\
		exit 1;\
	fi
	docker run \
		--rm \
		--privileged \
		-e CGO_ENABLED=1 \
		--env-file .release-env \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v `pwd`:/go/src/$(PACKAGE_NAME) \
		-w /go/src/$(PACKAGE_NAME) \
		ghcr.io/goreleaser/goreleaser-cross:${GOLANG_CROSS_VERSION} \
		release --clean --skip validate

.PHONY: release-dry-run release

###############################################################################
###                        Compile Solidity Contracts                       ###
###############################################################################

# Install the necessary dependencies, compile the solidity contracts found in the
# Cosmos EVM repository and then clean up the contracts data.
contracts-all: contracts-compile contracts-clean

# Clean smart contract compilation artifacts, dependencies and cache files
contracts-clean:
	@echo "Cleaning up the contracts directory..."
	@python3 ./scripts/compile_smart_contracts/compile_smart_contracts.py --clean

# Compile the solidity contracts found in the Cosmos EVM repository.
contracts-compile:
	@echo "Compiling smart contracts..."
	@python3 ./scripts/compile_smart_contracts/compile_smart_contracts.py --compile

# Add a new solidity contract to be compiled
contracts-add:
	@echo "Adding a new smart contract to be compiled..."
	@python3 ./scripts/compile_smart_contracts/compile_smart_contracts.py --add $(CONTRACT)

###############################################################################
###                                Localnet                                 ###
###############################################################################

localnet-build-env:
	# $(MAKE) -C contrib/images evmd-env
	@echo "Building localnet environment for mailchatd..."
	# Note: evmd-env target may need to be updated for mailchatd

localnet-build-nodes:
	@echo "Building localnet nodes for mailchatd..."
	# $(DOCKER) run --rm -v $(CURDIR)/.testnets:/data cosmos/mailchatd \
	#		  testnet init-files --validator-count 4 -o /data --starting-ip-address 192.168.10.2 --keyring-backend=test --chain-id=local-4221 --use-docker=true
	# docker compose up -d
	# Note: Docker image needs to be updated for mailchatd

localnet-stop:
	docker compose down

# localnet-start will run a 4-node testnet locally. The nodes are
# based off the docker images (to be configured for mailchatd)
localnet-start: localnet-stop localnet-build-env localnet-build-nodes


.PHONY: localnet-start localnet-stop localnet-build-env localnet-build-nodes

test-system: build
	ulimit -n 1300
	mkdir -p ./tests/systemtests/binaries/
	cp $(BUILDDIR)/$(EXAMPLE_BINARY) ./tests/systemtests/binaries/
	# $(MAKE) -C tests/systemtests test
	# Note: systemtests directory may need updates for mailchatd

mocks:
	@echo "--> generating mocks"
	@go get github.com/vektra/mockery/v2
	@go generate ./...
	@make format-go
