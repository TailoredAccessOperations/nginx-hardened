#!/bin/bash
# =============================================================================
# LINE-BY-LINE TESTING AND OPTIMIZATION SCRIPT
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/Users/x/Documents/GitHub/nginx-hardened"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  LINE-BY-LINE DOCKER BUILD TEST & OPTIMIZATION${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to test each stage
test_stage() {
    local stage=$1
    local dockerfile=$2
    
    echo -e "${YELLOW}Testing: $stage${NC}"
    
    if docker build --file "$dockerfile" --target "$stage" -t "nginx-test:$stage" "$PROJECT_DIR" 2>&1 | tee "$LOG_DIR/test-$stage.log"; then
        echo -e "${GREEN}✓ $stage built successfully${NC}"
        docker images "nginx-test:$stage" --format "  Size: {{.Size}}"
        return 0
    else
        echo -e "${RED}✗ $stage build failed${NC}"
        echo "  Check: $LOG_DIR/test-$stage.log"
        return 1
    fi
}

# Function to run security scan
security_scan() {
    echo -e "${YELLOW}Running security scan...${NC}"
    
    # Check for secrets
    if command -v gitleaks &> /dev/null; then
        gitleaks detect --source "$PROJECT_DIR" --verbose 2>&1 | tee "$LOG_DIR/security-gitleaks.log" || true
    fi
    
    # Check Dockerfile with hadolint
    if docker run --rm -i hadolint/hadolint < "$PROJECT_DIR/Dockerfile" 2>&1 | tee "$LOG_DIR/security-hadolint.log"; then
        echo -e "${GREEN}✓ Dockerfile linting passed${NC}"
    else
        echo -e "${YELLOW}⚠ Dockerfile linting found issues (check log)${NC}"
    fi
}

# Function to validate nginx config
validate_nginx() {
    echo -e "${YELLOW}Validating nginx configuration...${NC}"
    
    if docker run --rm nginx-test:runtime nginx -t 2>&1 | tee "$LOG_DIR/nginx-config-test.log"; then
        echo -e "${GREEN}✓ Nginx configuration valid${NC}"
    else
        echo -e "${RED}✗ Nginx configuration invalid${NC}"
        return 1
    fi
}

# Function to run performance test
performance_test() {
    echo -e "${YELLOW}Running performance tests...${NC}"
    
    # Start container
    docker run -d --name nginx-perf-test \
        -p 8888:80 \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        nginx-test:runtime
    
    sleep 3
    
    # Test with curl
    if curl -sf http://localhost:8888/healthz > /dev/null; then
        echo -e "${GREEN}✓ Health endpoint responding${NC}"
    else
        echo -e "${RED}✗ Health endpoint failed${NC}"
        docker logs nginx-perf-test
        docker stop nginx-perf-test && docker rm nginx-perf-test
        return 1
    fi
    
    # Install and run wrk if available
    if command -v wrk &> /dev/null; then
        echo -e "${BLUE}Running wrk benchmark...${NC}"
        wrk -t4 -c100 -d30s --latency http://localhost:8888/ 2>&1 | tee "$LOG_DIR/performance-wrk.log"
    else
        echo -e "${YELLOW}⚠ wrk not installed, skipping benchmark${NC}"
    fi
    
    # Clean up
    docker stop nginx-perf-test && docker rm nginx-perf-test
}

# Function to compare image sizes
compare_sizes() {
    echo -e "${YELLOW}Comparing image sizes...${NC}"
    echo ""
    echo " Sizes:"
    docker images --format "  {{.Repository}}:{{.Tag}} - {{.Size}}" | grep "nginx-test" | sort
    echo ""
}

# Main testing sequence
main() {
    cd "$PROJECT_DIR"
    
    # Test base stage
    test_stage "builder" "Dockerfile" || exit 1
    
    # Security scan
    security_scan
    
    # Build full image
    echo -e "${YELLOW}Building full production image...${NC}"
    docker build --file Dockerfile -t nginx-test:runtime "$PROJECT_DIR" 2>&1 | tee "$LOG_DIR/build-runtime.log"
    
    # Validate nginx config
    validate_nginx
    
    # Performance test
    performance_test
    
    # Compare sizes
    compare_sizes
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  TESTING COMPLETE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Logs available in: $LOG_DIR"
    echo ""
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
