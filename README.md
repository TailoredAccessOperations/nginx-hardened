# Modern Nginx with Extended Modules

Production-ready Nginx 1.26.0 with comprehensive module support, optimized for containerized environments.

## Features

- **Latest Nginx 1.26.0** with HTTP/3 (QUIC) support
- **Multi-platform builds** (amd64, arm64) with Docker Buildx
- **Security hardened** with non-root user, read-only filesystem support
- **Modern base image** (Debian Bookworm Slim)
- **BuildKit cache optimization** with mount caches
- **Kubernetes ready** with health checks and resource limits
- **Comprehensive monitoring** with metrics endpoint
- **SBOM generation** and security scanning (Trivy)

## Quick Start

### Docker Compose

```bash
# Start services
make up

# Check logs
make logs

# Test
curl http://localhost/healthz

# Stop services
make down
```

### Docker CLI

```bash
# Build image
make build

# Run container
docker run -d -p 80:80 --name nginx nginx:dev

# Test
curl http://localhost/healthz

# Stop
docker stop nginx
```

### Kubernetes

```bash
# Deploy to cluster
kubectl apply -f k8s/nginx-deployment.yaml

# Port forward to test
kubectl port-forward svc/nginx 8080:80

# View logs
kubectl logs -f deployment/nginx
```

## Build Targets

### Development Build (local only)
```bash
make build              # Single platform, docker daemon output
make build-ci           # Multi-platform, uses BuildKit cache
```

### Production Build (push to registry)
```bash
make push               # Multi-platform, push to Docker Hub
REGISTRY=ghcr.io make push-dev  # Change registry
```

## Configuration

### Environment Variables

Edit `.env.production` to customize:

```env
NGINX_VERSION=1.26.0
NGINX_CPU_LIMIT=2
NGINX_MEMORY_LIMIT=512M
HEALTHCHECK_INTERVAL=30s
```

### Nginx Configuration

- **nginx.conf** — Main server configuration
- **conf.d/health.conf** — Health check endpoints
- **conf.d/\*.conf** — Additional configs (mounted)

Add custom server blocks in `conf.d/` directory.

## Modules Included

### Core Modules
- `http_ssl_module` — TLS/SSL support
- `http_v2_module` — HTTP/2 support
- `http_v3_module` — HTTP/3 (QUIC) support
- `stream_module` — TCP/UDP load balancing
- `mail_module` — SMTP/IMAP proxy

### Extended Modules
- **ngx_brotli** — Brotli compression
- **ngx_devel_kit** — Development kit
- **headers-more-nginx-module** — Header manipulation
- **echo-nginx-module** — Echo/debug content
- **set-misc-nginx-module** — Variable manipulation
- **xss-nginx-module** — XSS filter
- **srcache-nginx-module** — Caching layer

## Security

### Container Security
- **Non-root user** (nginx:nginx)
- **Read-only filesystem** support
- **Minimal attack surface** — only runtime dependencies
- **SELinux compatible** labels
- **Dropped capabilities** — only NET_BIND_SERVICE

### Nginx Security Headers
```
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000
Content-Security-Policy: default-src 'self'
```

## Monitoring

### Health Check Endpoints

```bash
# Liveness check (is container running?)
curl http://localhost/healthz

# Readiness check (can handle requests?)
curl http://localhost/readyz

# Metrics (Prometheus format)
curl http://localhost/metrics
```

### Resource Limits (Docker Compose)

```yaml
deploy:
  limits:
    cpus: '2'
    memory: 512M
  reservations:
    cpus: '1'
    memory: 256M
```

## Performance

### Build Times (cold cache)
- Single platform: ~2m 20s
- Multi-platform (amd64 + arm64): ~4m 30s

### Image Size
- Final image: ~268 MB (includes all runtime deps)
- Buildable in ~300 seconds on modern hardware

### Runtime Performance
- Startup time: <1 second
- Worker connections: 10,000 per process
- Max open files: 65,535

## Development

### Quick Commands

```bash
make help           # Show all targets
make build          # Build dev image
make test           # Run integration tests
make shell          # Open shell in container
make lint           # Lint Dockerfile
make format         # Format config files
make security-check # Scan image with Trivy
make logs           # Tail container logs
```

### Testing

```bash
# Unit tests (config validation)
docker run --rm nginx:dev nginx -t

# Integration tests
make test

# Security scanning
make security-check

# SBOM generation
docker run --rm anchore/syft nginx:dev
```

## CI/CD

### GitHub Actions

Push to trigger automated:
1. **Build** — Multi-platform image build
2. **Test** — Container validation
3. **Scan** — Security scanning with Trivy
4. **Push** — Registry push (on main branch)
5. **SBOM** — Software Bill of Materials generation

### Docker Bake

```bash
# Dev build (single platform, local)
docker buildx bake -f docker-bake.hcl nginx-dev

# CI build (multi-platform, cached)
docker buildx bake -f docker-bake.hcl nginx-ci

# Production build (multi-platform, push)
docker buildx bake -f docker-bake.hcl nginx --push
```

## Troubleshooting

### Container won't start
```bash
# Check logs
docker compose logs nginx

# Validate config
docker run --rm nginx:dev nginx -t

# Check permissions
docker run --rm nginx:dev ls -la /var/cache/nginx
```

### Performance issues
```bash
# Check resource usage
docker stats nginx

# Monitor connections
docker exec nginx sh -c 'netstat -an | grep ESTABLISHED | wc -l'

# Check logs
docker logs nginx | grep error
```

### Build failures
```bash
# Clear cache
docker system prune -a

# Rebuild without cache
docker buildx bake -f docker-bake.hcl nginx-dev --no-cache

# Check BuildKit logs
docker buildx du
```

## Upgrade Path

### Update Nginx Version

1. Update `NGINX_VERSION` in:
   - `Dockerfile` (builder stage)
   - `docker-bake.hcl`
   - `.env.production`

2. Rebuild and test:
   ```bash
   make clean
   make build
   make test
   ```

3. Deploy:
   ```bash
   make push
   kubectl apply -f k8s/nginx-deployment.yaml
   ```

## Project Structure

```
.
├── Dockerfile              # Modern multi-stage build
├── docker-compose.yml      # Service definition (v3.9+)
├── docker-bake.hcl         # Buildx configuration
├── Makefile               # Common tasks
├── nginx.conf             # Main configuration
├── conf.d/
│   └── health.conf        # Health endpoints
├── html/                  # Static content
├── k8s/
│   └── nginx-deployment.yaml  # Kubernetes manifests
├── .github/workflows/
│   └── docker-build.yml   # CI/CD pipeline
├── .editorconfig          # Code style
└── .dockerignore          # Build context
```

## License

BSD 2-Clause License (Nginx license)

## Support

- Issues: GitHub Issues
- Docs: [Nginx Documentation](https://nginx.org/en/docs/)
- Docker: [Docker Documentation](https://docs.docker.com/)
