# Nginx Hardened Project Guide

This document provides comprehensive guidance for working with the Nginx hardened Docker image project.

---

## 1. Project Overview

### Description
Production-ready Nginx 1.26.0 with comprehensive module support, optimized for containerized environments. The project provides a security-hardened, multi-platform Docker image with extended Nginx modules and best-practice configurations.

### Key Technologies
- **Runtime**: Debian Bookworm Slim
- **Base Image**: Nginx 1.26.0 with HTTP/3 (QUIC) support
- **Container Platform**: Docker, Kubernetes
- **Build System**: Docker Buildx with Bake
- **CI/CD**: GitHub Actions
- **Package Registry**: GHCR (GitHub Container Registry)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Source Code                          │
│  (Dockerfile, nginx.conf, conf.d/, k8s/, .github/workflows)│
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   Multi-Stage Build                         │
│  ┌─────────────┐        ┌─────────────────────────────┐    │
│  │   Builder   │───────▶│   Runtime (Debian Slim)     │    │
│  │   Stage     │        │   - Non-root user (nginx)   │    │
│  │   (Debian)  │        │   - Minimal attack surface  │    │
│  └─────────────┘        └─────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────────┘
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
       ┌─────────┐  ┌──────────┐  ┌──────────┐
       │  amd64  │  │  arm64   │  │  Local   │
       │ Image   │  │  Image   │  │  Dev     │
       └─────────┘  └──────────┘  └──────────┘
```

---

## 2. Getting Started

### Prerequisites

| Requirement | Version/Notes |
|-------------|---------------|
| Docker | 24.0+ with Buildx enabled |
| Docker Compose | v3.9+ (optional) |
| kubectl | For Kubernetes deployment |
| Make | GNU Make 4.0+ |
| qemu-user-static | For multi-platform builds |

### Quick Start

#### Using Docker Compose (Recommended)

```bash
# Start services
make up

# Check status
make ps

# Test endpoints
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
curl http://localhost:8080/metrics

# View logs
make logs

# Stop services
make down
```

#### Using Docker CLI Directly

```bash
# Build development image (single platform)
make build

# Run container
docker run -d -p 8080:80 --name nginx nginx-hardened:dev

# Test
curl http://localhost:8080/healthz

# Stop
docker stop nginx
docker rm nginx
```

### Running Tests

```bash
# Run all tests (container startup, HTTP, config validation)
make test

# Security scanning
make security-check

# Validate docker-compose.yml
make validate-compose
```

---

## 3. Project Structure

```
.
├── .github/workflows/       # CI/CD pipeline
│   └── docker-build.yml    # Multi-platform build & push
├── .continue/rules/        # Continue AI assistant rules
├── conf.d/                 # Nginx configuration snippets
│   └── health.conf         # Health check endpoints
├── html/                   # Static content
├── k8s/                    # Kubernetes manifests
│   └── nginx-deployment.yaml
├── Dockerfile              # Multi-stage build definition
├── Dockerfile.hardened     # Security-hardened variant
├── docker-bake.hcl         # Buildx bake configuration
├── docker-compose.yml      # Local development compose
├── docker-compose.hardened.yml
├── nginx.conf              # Main Nginx configuration
├── Makefile                # Development tasks
└── README.md               # Project documentation
```

### Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build: builder stage compiles Nginx with modules, runtime stage creates minimal image |
| `docker-bake.hcl` | Defines build targets: `nginx` (prod), `nginx-dev` (local), `nginx-ci` (multi-platform) |
| `Makefile` | Development commands: build, test, deploy, lint, security |
| `nginx.conf` | Main Nginx configuration with security headers, gzip/brotli, rate limiting |
| `conf.d/health.conf` | Health check endpoints: `/healthz`, `/readyz`, `/metrics` |
| `k8s/nginx-deployment.yaml` | Complete K8s deployment: Deployment, Service, ConfigMap, HPA, NetworkPolicy |

---

## 4. Development Workflow

### Build Targets

```bash
# Development (single platform, local daemon)
make build              # or: docker buildx bake -f docker-bake.hcl nginx-dev

# CI/CD (multi-platform with cache)
make build-ci          # or: docker buildx bake -f docker-bake.hcl nginx-ci

# Production (multi-platform, push to registry)
make push              # or: docker buildx bake -f docker-bake.hcl nginx --push

# Push dev image to local Docker
make push-dev
```

### Customizing the Build

#### Environment Variables

Create `.env.production`:

```env
NGINX_VERSION=1.26.0
NGINX_CPU_LIMIT=2
NGINX_MEMORY_LIMIT=512M
HEALTHCHECK_INTERVAL=30s
REGISTRY=ghcr.io
IMAGE_NAME=nginx-hardened
```

#### Configuring Modules

The Dockerfile includes many Nginx modules. To modify:

1. Edit the Dockerfile's `configure` command
2. Ensure build dependencies are installed
3. Add git clone commands for new modules

### Testing

```bash
# Full test suite
make test

# Manual container testing
docker run --rm -d -p 8080:80 --name test-nginx nginx-hardened:dev
curl http://localhost:8080/
docker stop test-nginx

# Config validation
docker run --rm nginx-hardened:dev nginx -t
```

### CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/docker-build.yml`) runs:

1. **Build** - Multi-platform image build with BuildKit
2. **Test** - Container validation
3. **Security Scan** - Trivy vulnerability scanning
4. **SBOM** - Software Bill of Materials generation
5. **Sign** - Cosign image signing
6. **Push** - Registry push (main branch only)

---

## 5. Key Concepts

### Extended Nginx Modules

| Module | Purpose |
|--------|---------|
| `ngx_brotli` | Brotli compression |
| `ngx-fancyindex` | Enhanced directory listing |
| `headers-more-nginx-module` | Header manipulation |
| `echo-nginx-module` | Debug/echo endpoints |
| `set-misc-nginx-module` | Variable manipulation |
| `xss-nginx-module` | XSS filtering |
| `ngx_cache_purge` | Cache purge support |
| `nginx-module-vts` | Virtual host traffic status |
| `nginx-dav-ext-module` | WebDAV extensions |

### Security Features

- **Non-root user**: Runs as `nginx:nginx` (UID 101)
- **Read-only filesystem**: Supported via Kubernetes (`readOnlyRootFilesystem: true`)
- **Dropped capabilities**: Only `NET_BIND_SERVICE` added
- **Security headers**: X-Frame-Options, X-Content-Type-Options, CSP, HSTS
- ** SELinux**: Compatible labels

### Health Check Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/healthz` | Liveness probe - is container running? |
| `/readyz` | Readiness probe - can handle requests? |
| `/metrics` | Prometheus metrics in text format |

### Rate Limiting

Defined in `nginx.conf`:

| Zone | Rate | Purpose |
|------|------|---------|
| `general` | 10r/s | General requests |
| `api` | 30r/s | API endpoints |
| `addr` | Connection limiting | Per-IP connections |

---

## 6. Common Tasks

### Adding a New Server Block

Create a new config file in `conf.d/`:

```nginx
# conf.d/myapp.conf
server {
    listen 80;
    server_name myapp.example.com;

    location / {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Deploying to Kubernetes

```bash
# Apply deployment
kubectl apply -f k8s/nginx-deployment.yaml

# Port forward for testing
kubectl port-forward svc/nginx 8080:80

# Check pods
kubectl get pods -l app=nginx

# View logs
kubectl logs -l app=nginx

# Scale deployment
kubectl scale deployment nginx --replicas=5
```

### Updating Nginx Version

1. Update in `Dockerfile` (builder stage):
   ```dockerfile
   ENV NGINX_VERSION=1.27.0
   ```

2. Update in `docker-bake.hcl`:
   ```hcl
   variable "NGINX_VERSION" {
     default = "1.27.0"
   }
   ```

3. Update in `docker-compose.yml`:
   ```yaml
   args:
     NGINX_VERSION: "1.27.0"
   ```

4. Rebuild:
   ```bash
   make clean
   make build
   make test
   ```

### Using Custom Configuration

Mount custom configs in Docker Compose:

```yaml
volumes:
  - ./my-nginx.conf:/etc/nginx/nginx.conf:ro
  - ./my-conf.d:/etc/nginx/conf.d:ro
```

---

## 7. Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs nginx

# Validate configuration
docker run --rm nginx-hardened:dev nginx -t

# Check permissions
docker run --rm nginx-hardened:dev ls -la /var/cache/nginx
```

### Build Failures

```bash
# Clear Docker cache
docker system prune -a

# Rebuild without cache
docker buildx bake -f docker-bake.hcl nginx-dev --no-cache

# Check disk space
docker system df
```

### Performance Issues

```bash
# Check resource usage
docker stats nginx-web

# Monitor connections
docker exec nginx-web sh -c 'netstat -an | grep ESTABLISHED | wc -l'

# Check error logs
docker logs nginx-web | grep error
```

### Kubernetes Issues

```bash
# Describe pod for events
kubectl describe pod -l app=nginx

# Check pod logs
kubectl logs -l app=nginx --previous

# Verify configmap
kubectl get configmap nginx-config -o yaml
```

---

## 8. References

### Official Documentation
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Docker Buildx](https://docs.docker.com/build/buildx/)
- [Docker Bake](https://docs.docker.com/build/bake/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitHub Actions](https://docs.github.com/en/actions)

### Security Resources
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/)
- [Nginx Security Headers](https://www.nginx.com/resources/wiki/start/topics/examples/security_headers/)

### Module Documentation
- [ngx_brotli](https://github.com/google/ngx_brotli)
- [headers-more-nginx-module](https://github.com/openresty/headers-more-nginx-module)
- [nginx-module-vts](https://github.com/vozlt/nginx-module-vts)

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `make help` | Show all available targets |
| `make build` | Build development image |
| `make test` | Run test suite |
| `make up` | Start services with compose |
| `make down` | Stop services |
| `make push` | Build and push to registry |
| `make lint` | Lint Dockerfile |
| `make security-check` | Run Trivy scan |
| `make shell` | Open shell in container |
| `make clean` | Remove containers and images |
| `make inspect` | Inspect built image details |

---

*This guide is maintained as part of the project. Edit `.continue/rules/CONTINUE.md` to add project-specific tips or update sections.*