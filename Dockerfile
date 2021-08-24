FROM	alpine:latest AS build

ENV	NGINX_VERSION="1.20.1" \
	PCRE_VERSION="8.45" \
	NGINX_CLOUDFLARE_ZLIB_COMMIT="c43185ea33e45cd688673051744d068d96956d92" \
	NGINX_ACCEPT_LANGUAGE_COMMIT="2f69842f83dac77f7d98b41a2b31b13b87aeaba7" \
	NGINX_MORE_HEADERS_VERSION="0.33" \
	NGINX_ECHO_VERSION="0.62" \
	NGINX_NJS_VERSION="0.6.1"

COPY	patches/nginx_${NGINX_VERSION}_* /build/nginx-${NGINX_VERSION}/

RUN	set -x && \
	echo "nginx:x:1000:1000:nginx:/opt/nginx:" > /tmp/passwd && \
	echo "nginx:x:1000:x" > /tmp/group && \
	apk add --no-cache \
	build-base \
	curl \
	git \
	gnupg \
	linux-headers \
	openssl \
	openssl-dev \
	openssl-libs-static \
	pcre-dev \
	--repository=http://dl-cdn.alpinelinux.org/alpine/latest-stable/main && \
	mkdir -p /build && \
	cd /build && \
	set -- "B0F4253373F8F6F510D42178520A9993A1C052F8" && \
	gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys $@ || \
	gpg --batch --keyserver hkps://peegeepee.com --recv-keys $@ && \
	gpg --yes --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --import-ownertrust --yes && \
	cd /build && \
#
#	Google ngx_brotli module (formerly Eustas)
#
	git clone --depth 1 --single-branch --recursive https://github.com/google/ngx_brotli.git ngx_brotli && \
#
#	Cloudflare enhanced zlib
#
	curl --location --silent --output /build/zlib.tar.gz https://api.github.com/repos/cloudflare/zlib/tarball/${NGINX_CLOUDFLARE_ZLIB_COMMIT} && \
	mkdir -p /build/zlib && \
	tar -zxf /build/zlib.tar.gz --strip-components=1 -C /build/zlib && \
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
#	nginx_accept_language module
#
	curl --location --silent --output /build/nginx_accept_language.tar.gz https://api.github.com/repos/giom/nginx_accept_language_module/tarball/${NGINX_ACCEPT_LANGUAGE_COMMIT} && \
	mkdir -p /build/nginx_accept_language && \
	tar -zxf /build/nginx_accept_language.tar.gz --strip-components=1 -C /build/nginx_accept_language && \
#
#	nginx webserver
#
	curl --location --silent --output /build/nginx-${NGINX_VERSION}.tar.gz http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
	curl --location --silent --compressed --output /build/nginx-${NGINX_VERSION}.tar.gz.asc http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz.asc && \
	gpg --verify /build/nginx-${NGINX_VERSION}.tar.gz.asc && \
	tar -zxf nginx-${NGINX_VERSION}.tar.gz && \
#
#	Mozilla CA cert bundle
#
	curl --location --silent --compressed --output /build/cacert.pem https://curl.haxx.se/ca/cacert.pem && \
	curl --location --silent --compressed --output /build/cacert.pem.sha256 https://curl.haxx.se/ca/cacert.pem.sha256 && \
	sha256sum -c /build/cacert.pem.sha256 && \
#
#	Compile custom Cloudflare zlib
#
	cd /build/zlib && \
	./configure --static && \
	make install
#
#	Compile static nginx
#
	RUN set -x && \
	cd /build/nginx-${NGINX_VERSION} && \
	patch -p1 < nginx_${NGINX_VERSION}_hpack_push.patch && \
	patch -p1 < nginx_${NGINX_VERSION}_dynamic_tls_records.patch && \
	patch -p1 < nginx_${NGINX_VERSION}_resolver_conf_parsing.patch && \
	patch -p1 < nginx_${NGINX_VERSION}_remove_server_headers_combined.patch && \
	./configure \
		--with-cc-opt="-static -O3" \
		--with-ld-opt="-w -s -static" \
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
		--with-http_gunzip_module \
		--with-http_stub_status_module \
		--without-http_charset_module \
		--without-http_ssi_module \
		--without-http_userid_module \
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
		--add-module=/build/nginx_accept_language \
		--add-module=/build/headers-more-nginx-module-${NGINX_MORE_HEADERS_VERSION} \
		--add-module=/build/njs-${NGINX_NJS_VERSION}/nginx \
		--add-module=/build/echo-nginx-module-${NGINX_ECHO_VERSION} && \
	make -j`nproc` install && \
	file /opt/nginx/sbin/nginx && \
	mkdir -p /opt/nginx/var/client_body_temp /opt/nginx/var/proxy_temp && \
	cp /build/cacert.pem /opt/nginx && \
	rm /opt/nginx/conf/*.default /opt/nginx/conf/nginx.conf /opt/nginx/html/index.html

FROM	scratch

COPY	--from=build ["/tmp/passwd", "/tmp/group", "/etc/"]
COPY	--from=build ["/opt/nginx", "/opt/nginx"]

EXPOSE	5000
USER	nginx

ENTRYPOINT	["/opt/nginx/sbin/nginx"]
CMD		["-g", "daemon off;"]
