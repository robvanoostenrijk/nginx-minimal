#/!bin/bash
Color_Off='\033[0m'	# Text Reset
BWhite='\033[1;37m'	# White
BRed='\033[1;31m'	# Red
BGreen='\033[1;32m'	# Green

#
# Execute a number of sanity tests against the nginx-build
#
# Required tools:
# - curl (brew install curl)
# - openssl (brew install openssl)

docker build -t nginx-minimal .

docker run \
	--name nginx-minimal \
	--rm \
	--detach \
	--publish 5000:5000 \
	-v "$(pwd)/conf:/opt/nginx/conf" \
	-v "$(pwd)/logs:/opt/nginx/logs" \
	nginx-minimal

# OpenSSL Cert
LOCAL_FINGERPRINT=$(cat ./conf/localhost.crt | /usr/local/opt/openssl/bin/openssl x509 -fingerprint -noout -in /dev/stdin)
REMOTE_FINGERPRINT=$(/usr/local/opt/openssl/bin/openssl s_client -connect localhost:5000 < /dev/null 2>/dev/null | /usr/local/opt/openssl/bin/openssl x509 -fingerprint -noout -in /dev/stdin)

printf "${BWhite}[i]${Color_Off} SSL Certificate: "

if [ "$LOCAL_FINGERPRINT" == "$REMOTE_FINGERPRINT" ]; then
	printf "${BGreen}OK${Color_Off} ($REMOTE_FINGERPRINT)\n"
else
	printf "${BRed}FAIL${Color_Off} ($REMOTE_FINGERPRINT)\n"
fi

# HTTP/1.1 Support
HTTP_VERSION=$(/usr/local/opt/curl/bin/curl \
	--silent \
	--cacert "./conf/localhost.crt" \
	--http1.1 \
	--write-out "%{http_version}" \
	--output /dev/null \
	https://localhost:5000/)

printf "${BWhite}[i]${Color_Off} HTTP/1.1: "

if [ "$HTTP_VERSION" == "1.1" ]; then
	printf "${BGreen}OK${Color_Off} ($HTTP_VERSION)\n"
else
	printf "${BRed}FAIL${Color_Off} ($HTTP_VERSION)\n"
fi

# HTTP/2 Support
HTTP_VERSION=$(/usr/local/opt/curl/bin/curl \
	--silent \
	--cacert "./conf/localhost.crt" \
	--http2 \
	--write-out "%{http_version}" \
	--output /dev/null \
	https://localhost:5000/)

printf "${BWhite}[i]${Color_Off} HTTP/1.1: "

if [ "$HTTP_VERSION" == "2" ]; then
	printf "${BGreen}OK${Color_Off} ($HTTP_VERSION)\n"
else
	printf "${BRed}FAIL${Color_Off} ($HTTP_VERSION)\n"
fi

# TLS v1.1 Support
HTTP_RESULT=$(/usr/local/opt/curl/bin/curl \
	--silent \
	--cacert "./conf/localhost.crt" \
	--tlsv1.1 \
	--tls-max 1.1 \
	--ssl-reqd \
	--write-out "%{response_code}" \
	--output /dev/null \
	https://localhost:5000/)

printf "${BWhite}[i]${Color_Off} TLS v1.1: "

if [ "$HTTP_RESULT" == "200" ]; then
	printf "${BGreen}OK${Color_Off}\n"
else
	printf "${BRed}FAIL${Color_Off}\n"
fi

# TLS v1.2 Support
HTTP_RESULT=$(/usr/local/opt/curl/bin/curl \
	--silent \
	--cacert "./conf/localhost.crt" \
	--tlsv1.2 \
	--tls-max 1.2 \
	--ssl-reqd \
	--write-out "%{response_code}" \
	--output /dev/null \
	https://localhost:5000/)

printf "${BWhite}[i]${Color_Off} TLS v1.2: "

if [ "$HTTP_RESULT" == "200" ]; then
	printf "${BGreen}OK${Color_Off}\n"
else
	printf "${BRed}FAIL${Color_Off}\n"
fi

# TLS v1.3 Support
HTTP_RESULT=$(/usr/local/opt/curl/bin/curl \
	--silent \
	--cacert "./conf/localhost.crt" \
	--tlsv1.3 \
	--tls-max 1.3 \
	--ssl-reqd \
	--write-out "%{response_code}" \
	--output /dev/null \
	https://localhost:5000/)

printf "${BWhite}[i]${Color_Off} TLS v1.3: "

if [ "$HTTP_RESULT" == "200" ]; then
	printf "${BGreen}OK${Color_Off}\n"
else
	printf "${BRed}FAIL${Color_Off}\n"
fi

# Server Header
HTTP_HEADERS=$(/usr/local/opt/curl/bin/curl \
	--head \
	--silent \
	--cacert "./conf/localhost.crt" \
	https://localhost:5000/)

printf "${BWhite}[i]${Color_Off} Server Header: "

if grep -qi "server" <<< "$HTTP_HEADERS"; then
	printf "${BRed}FAIL${Color_Off}\n"
else
	printf "${BGreen}OK${Color_Off}\n"
	
fi

printf "${BWhite}[i]${Color_Off} HTTP/2 HPACK Efficiency: "

h2load -n 10 https://localhost:5000/headers | tail -6 |head -1

read -p "Press any key..."

docker stop nginx-minimal
