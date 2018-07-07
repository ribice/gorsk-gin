.PHONY: all
all: help

APP=gorsk
ALL_PACKAGES=$(shell go list ./... | grep -v "vendor")
VERSION?=1.0
BUILD?=$(shell git describe --tags --always --dirty)
DEP:=$(shell command -v dep 2> /dev/null)
SWAGGER:=$(shell command -v swagger 2> /dev/null)
RICHGO=$(shell command -v richgo 2> /dev/null)
BIN_DIR=bin
REPORTS_DIR=reports
APP_EXECUTABLE=./$(BIN_DIR)/$(APP)

ifeq ($(RICHGO),)
	GOBIN=go
else
	GOBIN=richgo
endif

help: ## Prints help for targets with comments
	@grep -E '^[a-zA-Z._-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

setup: ## Setup necessary dependencies and folder structure
ifndef DEP
	curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh
endif
ifndef SWAGGER
	$(GOBIN) get github.com/go-swagger/go-swagger/cmd/swagger
endif

update-deps: ## Update dependencies
	dep ensure -update

build-deps: ## Install dependencies
	dep ensure

compile: build-deps ## Build the app
	$(GOBIN) build -o $(APP_EXECUTABLE) ./cmd/api

build: test fmt compile ##Install dependencies and build the app

fmt: ## Run the code formatter
	$(GOBIN) fmt $(ALL_PACKAGES)

run: compile ## Build and start app locally (outside docker)
	GIN_MODE=release PORT=8080 ./$(APP_EXECUTABLE)

test: build-deps ## Run tests
	mkdir -p $(REPORTS_DIR)
	GIN_MODE=test $(GOBIN) test $(ALL_PACKAGES) -v -coverprofile ./$(REPORTS_DIR)/coverage

test-cover-html: test ## Run test and generate html coverage report
	@echo "mode: count" > coverage-all.out
	$(foreach pkg, $(ALL_PACKAGES),\
	$(GOBIN) test -coverprofile=coverage.out -covermode=count $(pkg);\
	tail -n +2 coverage.out >> coverage-all.out;)
	$(GOBIN) tool cover -html=coverage-all.out -o $(REPORTS_DIR)/coverage.html

generate-docs:
	cd ./cmd/api && swagger generate spec -o ./swaggerui/swagger.json --scan-models
