.PHONY: help build push test clean lint format security-check shell up down logs ps

REGISTRY ?= docker.io
IMAGE_NAME ?= nginx
NGINX_VERSION ?= 1.26.0
DOCKER_BUILDKIT ?= 1
COMPOSE_FILE ?= docker-compose.yml

# Color output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

build: ## Build Docker image (dev target, single platform)
	@echo "$(BLUE)Building Nginx image...$(NC)"
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker buildx bake -f docker-bake.hcl nginx-dev

build-ci: ## Build for CI/CD (multi-platform, cached)
	@echo "$(BLUE)Building for CI with cache...$(NC)"
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker buildx bake -f docker-bake.hcl nginx-ci

push: ## Build and push to registry
	@echo "$(BLUE)Building and pushing to $(REGISTRY)...$(NC)"
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker buildx bake -f docker-bake.hcl nginx --push

push-dev: ## Push dev image to local Docker daemon
	@echo "$(BLUE)Building dev image...$(NC)"
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker buildx bake -f docker-bake.hcl nginx-dev --load

test: ## Run container tests
	@echo "$(BLUE)Testing container...$(NC)"
	@docker run --rm -d -p 8080:80 --name test-nginx $(IMAGE_NAME):dev
	@sleep 3
	@echo "$(GREEN)✓ Container started$(NC)"
	@curl -sf http://localhost:8080/ > /dev/null && echo "$(GREEN)✓ HTTP OK$(NC)" || (echo "$(RED)✗ HTTP FAILED$(NC)" && exit 1)
	@docker run --rm $(IMAGE_NAME):dev nginx -t && echo "$(GREEN)✓ Config validation OK$(NC)" || (echo "$(RED)✗ Config validation FAILED$(NC)" && exit 1)
	@docker stop test-nginx
	@echo "$(GREEN)✓ All tests passed$(NC)"

shell: ## Open shell in running container
	@docker compose -f $(COMPOSE_FILE) exec nginx sh

logs: ## Tail container logs
	@docker compose -f $(COMPOSE_FILE) logs -f nginx

ps: ## Show running containers
	@docker compose -f $(COMPOSE_FILE) ps

up: ## Start services
	@echo "$(BLUE)Starting services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"

down: ## Stop services
	@echo "$(BLUE)Stopping services...$(NC)"
	@docker compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: down up ## Restart services

clean: ## Remove containers, images, and volumes
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	@docker compose -f $(COMPOSE_FILE) down -v
	@docker image prune -f
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

lint: ## Lint Dockerfile
	@echo "$(BLUE)Linting Dockerfile...$(NC)"
	@docker run --rm -i hadolint/hadolint < Dockerfile || true

format: ## Format HCL and YAML files
	@echo "$(BLUE)Formatting files...$(NC)"
	@command -v hclfmt >/dev/null 2>&1 && hclfmt -w docker-bake.hcl || echo "$(YELLOW)hclfmt not installed$(NC)"
	@command -v yamlfmt >/dev/null 2>&1 && yamlfmt -i docker-compose.yml || echo "$(YELLOW)yamlfmt not installed$(NC)"

security-check: ## Run security checks
	@echo "$(BLUE)Running security checks...$(NC)"
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy config . || true

version: ## Show Nginx version
	@docker run --rm $(IMAGE_NAME):dev nginx -v

inspect: ## Inspect built image
	@echo "$(BLUE)Image details:$(NC)"
	@docker inspect $(IMAGE_NAME):dev | jq '.[0] | {Architecture, Os, Size, Created, Labels}'

size: ## Show image size
	@echo "$(BLUE)Image size:$(NC)"
	@docker images $(IMAGE_NAME):dev --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

history: ## Show image build history
	@docker history $(IMAGE_NAME):dev --human --no-trunc

validate-compose: ## Validate docker-compose.yml
	@echo "$(BLUE)Validating docker-compose.yml...$(NC)"
	@docker compose -f $(COMPOSE_FILE) config > /dev/null && echo "$(GREEN)✓ Valid$(NC)" || echo "$(RED)✗ Invalid$(NC)"

.DEFAULT_GOAL := help
