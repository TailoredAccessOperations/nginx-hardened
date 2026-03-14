variable "REGISTRY" {
  default = "ghcr.io"
}

variable "IMAGE_NAME" {
  default = "nginx-hardened"
}

variable "NGINX_VERSION" {
  default = "1.26.0"
}

group "default" {
  targets = ["nginx"]
}

group "dev" {
  targets = ["nginx-dev"]
}

group "ci" {
  targets = ["nginx-ci"]
}

target "common" {
  dockerfile = "Dockerfile.hardened"
  context    = "."
  labels = {
    "org.opencontainers.image.title"       = "Hardened Nginx"
    "org.opencontainers.image.description" = "Production-hardened Nginx with security-first multi-stage build"
    "org.opencontainers.image.version"     = "${NGINX_VERSION}"
    "org.opencontainers.image.source"      = "https://github.com/TailoredAccessOperations/nginx-hardened"
    "org.opencontainers.image.vendor"      = "Security Team"
    "org.opencontainers.image.licenses"    = "BSD-2-Clause"
  }
}

target "nginx" {
  inherits = ["common"]
  tags = [
    "ghcr.io/tailoredaccessoperations/nginx-hardened:latest",
    "ghcr.io/tailoredaccessoperations/nginx-hardened:1.26.0",
    "ghcr.io/tailoredaccessoperations/nginx-hardened:${NGINX_VERSION}"
  ]
  args = {
    NGINX_VERSION = NGINX_VERSION
  }
  cache-from = ["type=gha"]
  cache-to   = ["type=gha,mode=max"]
}

target "nginx-dev" {
  inherits = ["nginx"]
  output   = ["type=docker"]
}

target "nginx-ci" {
  inherits = ["nginx"]
  platforms = ["linux/amd64", "linux/arm64"]
}
