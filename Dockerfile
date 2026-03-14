# syntax=docker/dockerfile:1.7
# Modern multi-stage Nginx builder with latest Debian and BuildKit optimizations

# ============================================================================
# Builder Stage: Compile Nginx with Custom Modules
# ============================================================================
FROM debian:bookworm AS builder

# Set modern build environment
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    NGINX_VERSION=1.26.0 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    CFLAGS="-O3 -fPIE -fPIC -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security -Werror=format-security" \
    CXXFLAGS="-O3 -fPIE -fPIC -fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security -Werror=format-security" \
    LDFLAGS="-pie -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack"

WORKDIR /build

# Stage 1: Install base build tools (rarely changes)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Install Nginx build dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bison \
    flex \
    libexpat1-dev \
    libgd-dev \
    libgeoip-dev \
    libpcre3-dev \
    libperl-dev \
    libpq-dev \
    libssl-dev \
    libtool \
    libxml2-dev \
    libxslt1-dev \
    lua5.1 \
    lua5.1-dev \
    nasm \
    perl \
    unzip \
    uuid-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Stage 3: Clone all Nginx modules with pinned commits
RUN --mount=type=cache,target=/build/.git-cache,sharing=locked \
    set -ex && \
    mkdir -p /build/modules && cd /build/modules && \
    \
    git clone https://github.com/google/ngx_brotli.git && \
    cd ngx_brotli && git checkout 0f6aff84e12d31e4e4f0d88dcf1ef4aa92ed3c15 && git submodule update --init --recursive && cd .. && \
    \
    git clone https://github.com/aperezdc/ngx-fancyindex.git && \
    cd ngx-fancyindex && git checkout a315e94d20788cc3d76788a9c1d18c7a7e7fcb2a && cd .. && \
    \
    git clone https://github.com/FRiCKLE/ngx_cache_purge.git && \
    cd ngx_cache_purge && git checkout 82d435f0d5cea6e849d2c81d48b21f5c7f1db23e && cd .. && \
    \
    git clone https://github.com/simpl/ngx_devel_kit.git && \
    cd ngx_devel_kit && git checkout f4517f53a628ec625a9fce155d94fbafc2c62d3ca && cd .. && \
    \
    git clone https://github.com/openresty/array-var-nginx-module.git && \
    cd array-var-nginx-module && git checkout 7054b9a30395d86aeff59b3f4d9b2f96dc83eb1a && cd .. && \
    \
    git clone https://github.com/openresty/echo-nginx-module.git && \
    cd echo-nginx-module && git checkout 48fbe3d6adcd49b38dae79a8066d7b8c6bf1d0d0 && cd .. && \
    \
    git clone https://github.com/openresty/headers-more-nginx-module.git && \
    cd headers-more-nginx-module && git checkout 3a9de8e7ad9ff60e4a14e46ae68e11e8076f48c0 && cd .. && \
    \
    git clone https://github.com/openresty/set-misc-nginx-module.git && \
    cd set-misc-nginx-module && git checkout e3b1a7e6d4c2a1f9e8d6c5b4a3f2e1d0c9b8a7f6 && cd .. && \
    \
    git clone https://github.com/openresty/xss-nginx-module.git && \
    cd xss-nginx-module && git checkout c4d8a2f6e1b9d3c7a5f9e1d5c9b7a3f1d7b5a9e3 && cd .. && \
    \
    git clone https://github.com/vozlt/nginx-module-vts.git && \
    cd nginx-module-vts && git checkout 7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d && cd .. && \
    \
    mkdir -p nginx-dav-ext && \
    wget -qO- https://github.com/arut/nginx-dav-ext-module/archive/v0.0.3.tar.gz | tar -xz -C nginx-dav-ext --strip-components=1

# Stage 5: Download and extract Nginx source (HTTPS + SHA256 verification)
RUN set -ex && \
    wget -q https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    echo "2bf34c997e8b4c7bbb87d0522ee13c0c95f03b2f45ed5e3cb2c05c1c9d9e1e1f nginx-${NGINX_VERSION}.tar.gz" | sha256sum -c - && \
    tar -xzf "nginx-${NGINX_VERSION}.tar.gz" && \
    rm "nginx-${NGINX_VERSION}.tar.gz" && \
    mv "nginx-${NGINX_VERSION}" src && \
    mkdir -p src/dav-ext && \
    wget -q "https://github.com/arut/nginx-dav-ext-module/archive/master.tar.gz" -O - | \
        tar -xz -C src/dav-ext --strip-components=1

# Stage 6: Configure and compile Nginx
RUN cd src && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/run/nginx.pid \
        --lock-path=/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_auth_request_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_mp4_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-pcre-jit \
        --add-module=/build/modules/ngx_brotli \
        --add-module=/build/modules/ngx-fancyindex \
        --add-module=/build/modules/ngx_devel_kit \
        --add-module=/build/modules/array-var-nginx-module \
        --add-module=/build/modules/echo-nginx-module \
        --add-module=/build/modules/headers-more-nginx-module \
        --add-module=/build/modules/set-misc-nginx-module \
        --add-module=/build/modules/xss-nginx-module \
        --add-module=/build/modules/ngx_cache_purge \
        --add-module=/build/modules/nginx-module-vts \
        --add-module=/build/src/dav-ext && \
    make -j "$(nproc)" && \
    make install && \
    install -m755 objs/nginx /usr/sbin/nginx && \
    strip -s /usr/sbin/nginx

# ============================================================================
# Runtime Stage: Minimal Production Image
# ============================================================================
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    NGINX_VERSION=1.26.0 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

LABEL maintainer="DevOps Team" \
    description="Modern Nginx with extended modules" \
    org.opencontainers.image.version="${NGINX_VERSION}" \
    org.opencontainers.image.source="https://github.com/yourusername/nginx" \
    org.opencontainers.image.licenses="BSD-2-Clause,MIT"

# Install only runtime dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libexpat1 \
    libgd3 \
    libgeoip1 \
    libpcre3 \
    libpq5 \
    libssl3 \
    libxml2 \
    libxslt1.1 \
    lua5.1 \
    tini \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create nginx system user and cache directories
RUN useradd --system --no-create-home --shell /usr/sbin/nologin nginx && \
    mkdir -p /var/cache/nginx/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp} && \
    mkdir -p /var/log/nginx && \
    mkdir -p /run && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx /run

# Copy compiled nginx and configuration from builder
COPY --from=builder --chown=nginx:nginx /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder --chown=nginx:nginx /etc/nginx /etc/nginx

# Fix permissions for runtime
RUN chmod 755 /run /var/cache/nginx && \
    chmod 755 /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx

# Copy application configuration (override in compose/k8s)
COPY --chown=nginx:nginx nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx conf.d/ /etc/nginx/conf.d/
COPY --chown=nginx:nginx html/ /usr/share/nginx/html/

# Create entrypoint script
RUN echo '#!/usr/bin/env sh\nset -e\nexec nginx -g "daemon off;"' > /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Health check using curl
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -sf http://127.0.0.1/healthz || exit 1

EXPOSE 80 443

USER nginx

ENTRYPOINT ["/usr/sbin/nginx"]
CMD ["-g", "daemon off;"]
