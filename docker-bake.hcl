variable "REGISTRY" {
  default = "docker.io"
}

variable "IMAGE_NAME" {
  default = "nginx"
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
  dockerfile = "Dockerfile"
  context    = "."
  labels = {
    "org.opencontainers.image.title"       = "Custom Nginx"
    "org.opencontainers.image.description" = "Production-ready Nginx with extended modules"
    "org.opencontainers.image.version"     = "${NGINX_VERSION}"
    "org.opencontainers.image.url"         = "https://github.com/yourusername/nginx"
    "org.opencontainers.image.vendor"      = "Your Organization"
  }
}

target "nginx" {
  inherits = ["common"]
  tags = [
    "${REGISTRY}/${IMAGE_NAME}:latest",
    "${REGISTRY}/${IMAGE_NAME}:${NGINX_VERSION}"
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
  tags     = ["${IMAGE_NAME}:dev"]
}

target "nginx-ci" {
  inherits = ["nginx"]
  platforms = ["linux/amd64", "linux/arm64"]
}
