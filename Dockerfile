ARG NGINX_VERSION="1.16.0"

FROM alpine:latest AS build

ARG NGINX_VERSION

ENV BROTLI_VERSION="1.0.7" \
	NGINX_BROTLI_COMMIT="8104036af9cff4b1d34f22d00ba857e2a93a243c" \
	NGINX_CLOUDFLARE_BROTLI_COMMIT="7df1e381d7abefa53a226306057453a202cd60c2" \
	NGINX_CLOUDFLARE_ZLIB_COMMIT="af9ef2e94cb9ffebc8dc6cc6d856e494880d869b" \
	NGINX_MORE_HEADERS_VERSION="0.33" \
	NGINX_ECHO_VERSION="0.61" \
	NGINX_NJS_VERSION="0.3.3"

COPY	patches/nginx_${NGINX_VERSION}_dynamic_tls_records_spdy.patch \
		patches/nginx_${NGINX_VERSION}_http2_spdy.patch \
		patches/nginx_${NGINX_VERSION}_hpack_push_remove_server_header.patch \
		/build/nginx-${NGINX_VERSION}/

RUN	set -x && \
	echo "nginx:x:1000:1000:nginx:/usr/src/app:" > /tmp/passwd && \
	echo "nginx:x:1000:x" > /tmp/group && \
	apk add --no-cache --virtual .build-deps \
	clang \
	build-base \
	linux-headers \
	gnupg \
	curl \
	perl \
	git \
	bash \
#	zlib-dev \
	pcre-dev \
	openssl-dev \
	--repository=http://dl-cdn.alpinelinux.org/alpine/edge/main && \
	mkdir -p /build && \
	cd /build && \
	for key in \
	520A9993A1C052F8 \
	; do \
	gpg --batch --keyserver hkp://ha.pool.sks-keyservers.net --recv-keys "$key" || \
	gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
	gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
	done && \
	cd /build && \
#
#	Eustas ngx_brotli module
#
	#curl --location --silent --output /build/ngx_brotli.tar.gz https://api.github.com/repos/eustas/ngx_brotli/tarball/${NGINX_BROTLI_COMMIT} && \
	#mkdir -p /build/ngx_brotli && \
	#tar -zxf /build/ngx_brotli.tar.gz --strip-components=1 -C /build/ngx_brotli && \
	#curl --location --silent --output /build/brotli-${BROTLI_VERSION}.tar.gz https://github.com/google/brotli/archive/v${BROTLI_VERSION}.tar.gz && \
	#tar -zxf /build/brotli-${BROTLI_VERSION}.tar.gz --strip-components=1 -C /build/ngx_brotli/deps/brotli && \
#
#	Cloudflare ngx_brotli module
#
	git clone --depth 1 --single-branch --recursive https://github.com/cloudflare/ngx_brotli_module.git ngx_brotli && \
#
#	Cloudflare enhanced zlib
#
	curl --location --silent --output /build/zlib.tar.gz https://api.github.com/repos/cloudflare/zlib/tarball/${NGINX_CLOUDFLARE_ZLIB_COMMIT} && \
	mkdir -p /build/zlib && \
	tar -zxf /build/zlib.tar.gz --strip-components=1 -C /build/zlib && \
	#git clone --depth 1 --single-branch --branch gcc.amd64 https://github.com/cloudflare/zlib.git zlib && \
#
#	nginx_more_headers module
#
	curl --location --silent --output /build/ngx_more_headers.tar.gz https://github.com/openresty/headers-more-nginx-module/archive/v${NGINX_MORE_HEADERS_VERSION}.tar.gz && \
	tar -zxf /build/ngx_more_headers.tar.gz && \
#
#	nginx_echo module
#
	curl --location --silent --output /build/nginx_echo.tar.gz https://github.com/openresty/echo-nginx-module/archive/v${NGINX_ECHO_VERSION}.tar.gz && \
	tar -zxf /build/nginx_echo.tar.gz && \
#
#	nginx_njs module
#
	curl --location --silent --output /build/nginx_njs.tar.gz https://github.com/nginx/njs/archive/${NGINX_NJS_VERSION}.tar.gz && \
	tar -zxf /build/nginx_njs.tar.gz && \
#
#	nginx webserver
#
	curl --location --silent --output /build/nginx-${NGINX_VERSION}.tar.gz http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
	curl --location --silent --output /build/nginx-${NGINX_VERSION}.tar.gz.asc http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc && \
	gpg --verify --always-trust /build/nginx-${NGINX_VERSION}.tar.gz.asc && \
	tar -zxf nginx-${NGINX_VERSION}.tar.gz && \
#
#	Mozilla CA cert bundle
#
	curl --location --silent --output /build/cacert.pem https://curl.haxx.se/ca/cacert.pem && \
	curl --location --silent --output /build/cacert.pem.sha256 https://curl.haxx.se/ca/cacert.pem.sha256 && \
	sha256sum -c /build/cacert.pem.sha256 && \
#
#	Compile custom Cloudflare zlib
#
	cd /build/zlib && \
	./configure --static && \
	make install && \
#
#	Compile static nginx
#
	cd /build/nginx-${NGINX_VERSION} && \
	patch -p1 < nginx_${NGINX_VERSION}_http2_spdy.patch && \
	patch -p1 < nginx_${NGINX_VERSION}_hpack_push_remove_server_header.patch && \
	patch -p1 < nginx_${NGINX_VERSION}_dynamic_tls_records_spdy.patch && \
	./configure \
		--with-cc=/usr/bin/clang \
		--with-cc-opt="-static -Wno-sign-compare -O3" \
		--with-ld-opt="-static" \
		--with-zlib-opt="-O3" \
		--with-pcre-opt="-O3" \
		--with-pcre-jit \
		--user=nginx \
		--group=nginx \
		--prefix=/opt/nginx \
		--http-client-body-temp-path=/opt/nginx/var/client_body_temp \
		--http-proxy-temp-path=/opt/nginx/var/proxy_temp \
		--with-threads \
		--with-http_ssl_module \
		--with-http_v2_module \
		--with-http_v2_hpack_enc \
		--with-http_spdy_module \
		--with-http_gunzip_module \
		--with-http_stub_status_module \
		--without-http_charset_module \
		--without-http_ssi_module \
		--without-http_userid_module \
		--without-http_access_module \
		--without-http_auth_basic_module \
		--without-http_mirror_module \
		--without-http_autoindex_module \
		--without-http_geo_module \
		--without-http_fastcgi_module \
		--without-http_uwsgi_module \
		--without-http_scgi_module \
		--without-http_grpc_module \
		--without-http_memcached_module \
		--add-module=/build/ngx_brotli \
		--add-module=/build/headers-more-nginx-module-${NGINX_MORE_HEADERS_VERSION} \
		--add-module=/build/njs-${NGINX_NJS_VERSION}/nginx \
		--add-module=/build/echo-nginx-module-${NGINX_ECHO_VERSION} && \
	CC=/usr/bin/clang make install && \
	strip /opt/nginx/sbin/nginx && \
	file /opt/nginx/sbin/nginx && \
	mkdir -p /opt/nginx/var/client_body_temp /opt/nginx/var/proxy_temp && \
	cp /build/cacert.pem /opt/nginx

FROM scratch

ARG NGINX_VERSION

LABEL	name="nginx-minimal ${NGINX_VERSION}" \
		version="${NGINX_VERSION}" \
		description="Static nginx compiled with clang including TLS v1.3, HTTP/2, SPDY 3.1, HPACK, brotli module, njs module, more headers module & echo module"

COPY --from=build ["/tmp/passwd", "/tmp/group", "/etc/"]
COPY --from=build ["/opt/nginx", "/opt/nginx"]

ENTRYPOINT ["/opt/nginx/sbin/nginx"]
CMD ["-g", "daemon off;"]
