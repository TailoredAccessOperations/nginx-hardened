#!/bin/bash
# =============================================================================
# COMPREHENSIVE DEBIAN + DOCKER NGINX OPTIMIZATION SCRIPT
# Version: 2.0.0
# Description: Systematic server hardening and performance optimization
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/var/log/nginx-optimizer-$(date +%Y%m%d-%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Configuration
NGINX_VERSION="1.26.0"
DOCKER_VERSION="latest"
BUILDKIT_VERSION="latest"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  NGINX-HARDENED DEBIAN OPTIMIZATION SCRIPT${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# =============================================================================
# STEP 1: SYSTEM REQUIREMENTS CHECK
# =============================================================================
check_system_requirements() {
    echo -e "${YELLOW}[STEP 1/10] Checking system requirements...${NC}"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ This script must be run as root${NC}"
        exit 1
    fi
    
    # Check Debian version
    if ! command -v lsb_release &> /dev/null; then
        apt-get update && apt-get install -y lsb-release
    fi
    
    DEBIAN_VERSION=$(lsb_release -rs)
    echo -e "${GREEN}✓ Debian version: $DEBIAN_VERSION${NC}"
    
    # Check architecture
    ARCH=$(uname -m)
    echo -e "${GREEN}✓ Architecture: $ARCH${NC}"
    
    # Check RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 2048 ]; then
        echo -e "${YELLOW}⚠ Warning: Less than 2GB RAM detected. Build may be slow.${NC}"
    else
        echo -e "${GREEN}✓ RAM: ${TOTAL_RAM}MB${NC}"
    fi
    
    # Check disk space
    DISK_SPACE=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$DISK_SPACE" -lt 10240 ]; then
        echo -e "${RED}✗ Error: Less than 10GB free disk space${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Disk space: ${DISK_SPACE}MB available${NC}"
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        echo -e "${RED}✗ Error: No internet connectivity${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Internet connectivity OK${NC}"
    
    echo ""
}

# =============================================================================
# STEP 2: SYSTEM UPDATE AND ESSENTIAL PACKAGES
# =============================================================================
update_system() {
    echo -e "${YELLOW}[STEP 2/10] Updating system and installing essential packages...${NC}"
    
    # Update package lists
    apt-get update
    
    # Upgrade existing packages
    apt-get upgrade -y
    
    # Install essential packages
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        git \
        wget \
        vim \
        nano \
        htop \
        iotop \
        net-tools \
        dnsutils \
        jq \
        tree \
        unzip \
        p7zip-full
    
    echo -e "${GREEN}✓ System updated and essential packages installed${NC}"
    echo ""
}

# =============================================================================
# STEP 3: KERNEL OPTIMIZATION
# =============================================================================
optimize_kernel() {
    echo -e "${YELLOW}[STEP 3/10] Optimizing kernel parameters...${NC}"
    
    # Create sysctl configuration
    cat > /etc/sysctl.d/99-nginx-optimized.conf << 'EOF'
# Network performance tuning
net.core.netdev_max_backlog = 65536
net.core.somaxconn = 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_slow_start_after_idle = 0

# File descriptors
fs.file-max = 2097152
fs.nr_open = 2097152

# Virtual memory
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# Security
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
EOF
    
    # Apply sysctl settings
    sysctl --system
    
    # Increase file descriptor limits
    cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
    
    # Update systemd limits
    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=1048576
EOF
    
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Kernel optimized${NC}"
    echo ""
}

# =============================================================================
# STEP 4: DOCKER INSTALLATION AND CONFIGURATION
# =============================================================================
install_docker() {
    echo -e "${YELLOW}[STEP 4/10] Installing and configuring Docker...${NC}"
    
    # Remove old Docker versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Configure Docker daemon for performance
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true,
  "userland-proxy": false,
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  }
}
EOF
    
    # Restart Docker
    systemctl restart docker
    
    # Verify Docker installation
    if ! docker --version &> /dev/null; then
        echo -e "${RED}✗ Docker installation failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Docker installed: $(docker --version)${NC}"
    echo ""
}

# =============================================================================
# STEP 5: DOCKER BUILDX SETUP
# =============================================================================
setup_buildx() {
    echo -e "${YELLOW}[STEP 5/10] Setting up Docker Buildx...${NC}"
    
    # Create buildx builder with optimized settings
    docker buildx create --use --name optimized-builder --driver docker-container \
        --driver-opt image=moby/buildkit:latest \
        --driver-opt network=host \
        --buildkitd-flags '--allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host' || true
    
    # Inspect builder
    docker buildx inspect --bootstrap
    
    # Set up BuildKit cache
    mkdir -p /var/cache/buildkit
    
    echo -e "${GREEN}✓ Buildx configured${NC}"
    echo ""
}

# =============================================================================
# STEP 6: NGINX BUILD OPTIMIZATION
# =============================================================================
build_nginx() {
    echo -e "${YELLOW}[STEP 6/10] Building optimized nginx image...${NC}"
    
    cd /opt/nginx-hardened 2>/dev/null || cd /root/nginx-hardened 2>/dev/null || cd .
    
    # Clean up old builds
    docker system prune -f --volumes 2>/dev/null || true
 
    # Build with optimizations
    export DOCKER_BUILDKIT=1
    export BUILDKIT_PROGRESS=plain
    
    echo -e "${BLUE}Building production image...${NC}"
    docker buildx build \
        --file Dockerfile.production \
        --tag nginx-hardened:production-latest \
        --tag nginx-hardened:production-${NGINX_VERSION} \
        --build-arg NGINX_VERSION=${NGINX_VERSION} \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --cache-from type=local,src=/var/cache/buildkit \
        --cache-to type=local,dest=/var/cache/buildkit,mode=max \
        --progress=plain \
        --load \
        . 2>&1 | tee /var/log/nginx-build.log
    
    # Build hardened image
    echo -e "${BLUE}Building hardened image...${NC}"
    docker buildx build \
        --file Dockerfile.hardened \
        --tag nginx-hardened:hardened-latest \
        --tag nginx-hardened:hardened-${NGINX_VERSION} \
        --build-arg NGINX_VERSION=${NGINX_VERSION} \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --cache-from type=local,src=/var/cache/buildkit \
        --cache-to type=local,dest=/var/cache/buildkit,mode=max \
        --progress=plain \
        --load \
        . 2>&1 | tee -a /var/log/nginx-build.log
    
    # Verify builds
    echo -e "${BLUE}Verifying builds...${NC}"
    docker images | grep nginx-hardened
    
    echo -e "${GREEN}✓ Nginx images built successfully${NC}"
    echo ""
}

# =============================================================================
# STEP 7: PERFORMANCE TESTING
# =============================================================================
test_performance() {
    echo -e "${YELLOW}[STEP 7/10] Running performance tests...${NC}"
    
    # Start container for testing
    docker run -d --name nginx-test \
        -p 8080:80 \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --cap-add NET_BIND_SERVICE \
        --read-only \
        --tmpfs /tmp:noexec,nosuid,size=100m \
        --tmpfs /var/cache/nginx:size=200m \
        --tmpfs /var/log/nginx:size=100m \
        --tmpfs /run:size=10m \
        nginx-hardened:production-latest
    
    # Wait for container to be ready
    echo -e "${BLUE}Waiting for container to start...${NC}"
    sleep 5
    
    # Test health endpoint
    echo -e "${BLUE}Testing health endpoint...${NC}"
    if curl -sf http://localhost:8080/healthz > /dev/null; then
        echo -e "${GREEN}✓ Health check passed${NC}"
    else
        echo -e "${RED}✗ Health check failed${NC}"
        docker logs nginx-test
        docker stop nginx-test && docker rm nginx-test
        exit 1
    fi
    
    # Install wrk for benchmarking if not present
    if ! command -v wrk &> /dev/null; then
        echo -e "${BLUE}Installing wrk for benchmarking...${NC}"
        apt-get install -y build-essential libssl-dev git
        git clone https://github.com/wg/wrk.git /tmp/wrk
        cd /tmp/wrk
        make -j$(nproc)
        cp wrk /usr/local/bin/
        cd -
    fi
    
    # Run benchmark
    echo -e "${BLUE}Running performance benchmark...${NC}"
    echo "Testing with 12 threads, 400 connections for 30 seconds..."
    wrk -t12 -c400 -d30s --latency http://localhost:8080/ 2>&1 | tee /var/log/nginx-benchmark.log
    
    # Clean up test container
    docker stop nginx-test && docker rm nginx-test
    
    echo -e "${GREEN}✓ Performance tests completed${NC}"
    echo ""
}

# =============================================================================
# STEP 8: SECURITY HARDENING
# =============================================================================
harden_security() {
    echo -e "${YELLOW}[STEP 8/10] Applying security hardening...${NC}"
    
    # Install and configure fail2ban
    apt-get install -y fail2ban
    
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
EOF
    
    # Create nginx filter for fail2ban
    cat > /etc/fail2ban/filter.d/nginx-noscript.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*GET .*(\.php|\.asp|\.exe|\.pl|\.cgi|\scfg)
ignoreregex =
EOF
    
    cat > /etc/fail2ban/filter.d/nginx-badbots.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*(libwww-perl|python-requests|curl|wget)
ignoreregex =
EOF
    
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    # Configure UFW (Uncomplicated Firewall)
    apt-get install -y ufw
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    
    # Disable unused services
    systemctl disable apt-daily.service 2>/dev/null || true
    systemctl disable apt-daily-upgrade.service 2>/dev/null || true
    systemctl disable man-db.service 2>/dev/null || true
    
    # Secure shared memory
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
    
    # Remove unnecessary packages
    apt-get autoremove -y
    apt-get autoclean
    
    echo -e "${GREEN}✓ Security hardening applied${NC}"
    echo ""
}

# =============================================================================
# STEP 9: MONITORING SETUP
# =============================================================================
setup_monitoring() {
    echo -e "${YELLOW}[STEP 9/10] Setting up monitoring...${NC}"
    
    # Install Prometheus Node Exporter
    NODE_EXPORTER_VERSION="1.7.0"
    cd /tmp
    wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
    tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
    cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
    rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"*
    
    # Create systemd service
    cat > /etc/systemd/system/node-exporter.service << 'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --path.rootfs=/host
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
    systemctl daemon-reload
    systemctl enable node-exporter
    systemctl start node-exporter
    
    # Install cadvisor for container monitoring
    docker run -d --name cadvisor \
        --restart=unless-stopped \
        --volume=/:/rootfs:ro \
        --volume=/var/run:/var/run:ro \
        --volume=/sys:/sys:ro \
        --volume=/var/lib/docker/:/var/lib/docker:ro \
        --volume=/dev/disk/:/dev/disk:ro \
        --publish=8081:8080 \
        --detach=true \
        --name=cadvisor \
        gcr.io/cadvisor/cadvisor:latest
    
    echo -e "${GREEN}✓ Monitoring configured${NC}"
    echo -e "${BLUE}  - Node Exporter: http://localhost:9100/metrics${NC}"
    echo -e "${BLUE}  - cAdvisor: http://localhost:8081${NC}"
    echo ""
}

# =============================================================================
# STEP 10: FINAL VERIFICATION AND SUMMARY
# =============================================================================
finalize() {
    echo -e "${YELLOW}[STEP 10/10] Final verification...${NC}"
    
    # Run nginx config test
    docker run --rm nginx-hardened:production-latest nginx -t
    
    # Display summary
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  OPTIMIZATION COMPLETE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}System Information:${NC}"
    echo "  - Debian Version: $(lsb_release -ds)"
    echo "  - Kernel: $(uname -r)"
    echo "  - Docker: $(docker --version)"
    echo "  - Nginx Version: ${NGINX_VERSION}"
    echo ""
    echo -e "${BLUE}Installed Images:${NC}"
    docker images --format "  - {{.Repository}}:{{.Tag}} ({{.Size}})" | grep nginx-hardened
    echo ""
    echo -e "${BLUE}Services:${NC}"
    echo "  - Docker: $(systemctl is-active docker)"
    echo "  - Fail2ban: $(systemctl is-active fail2ban)"
    echo "  - UFW: $(ufw status | head -1)"
    echo "  - Node Exporter: $(systemctl is-active node-exporter 2>/dev/null || echo 'not installed')"
    echo ""
    echo -e "${BLUE}Performance Metrics:${NC}"
    if [ -f /var/log/nginx-benchmark.log ]; then
        grep "Requests/sec" /var/log/nginx-benchmark.log 2>/dev/null || echo "  - Benchmark results in /var/log/nginx-benchmark.log"
    fi
    echo ""
    echo -e "${BLUE}Log Files:${NC}"
    echo "  - Build log: /var/log/nginx-build.log"
    echo "  - Benchmark: /var/log/nginx-benchmark.log"
    echo "  - Setup log: $LOG_FILE"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Run: docker compose -f docker-compose.production.yml up -d"
    echo "  2. Test: curl http://localhost:8080/healthz"
    echo "  3. Monitor: htop, docker stats"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    check_system_requirements
    update_system
    optimize_kernel
    install_docker
    setup_buildx
    build_nginx
    test_performance
    harden_security
    setup_monitoring
    finalize
}

# Run main function
main "$@"
