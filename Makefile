# Resilience Network — build targets.
#
# The Go cloud API is deployed to AWS Lambda (provided.al2023, arm64) and
# packaged by the CDK app under infra/. `make lambda-build` cross-compiles the
# Go Lambda entrypoint (cloud/cmd/lambda) into a `bootstrap` binary that the CDK
# Function construct zips and uploads.
#
# Before running Go targets, source the toolchain env:
#   source .toolchain/env.sh

# Output directory for the Lambda bundle the CDK app consumes.
LAMBDA_DIR := cloud/build/lambda
LAMBDA_BIN := $(LAMBDA_DIR)/bootstrap

.PHONY: lambda-build
lambda-build: ## Cross-compile the Go API Lambda to a provided.al2023 bootstrap (linux/arm64).
	@mkdir -p $(LAMBDA_DIR)
	cd cloud && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
		go build -tags lambda.norpc -ldflags="-s -w" \
		-o ../$(LAMBDA_BIN) ./cmd/lambda
	@echo "built $(LAMBDA_BIN)"
	@file $(LAMBDA_BIN) || true

.PHONY: lambda-clean
lambda-clean: ## Remove the built Lambda bundle.
	rm -rf $(LAMBDA_DIR)

.PHONY: help
help: ## List available targets.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "%-16s %s\n", $$1, $$2}'
