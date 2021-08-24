#### nginx-minimal ####

`nginx-minimal` is a distroless [nginx](https://nginx.org) docker build.

It consists of a minimal static compiled nginx with:

* HTTP/2
* Removed server headers
* Local /etc/resolv.conf support
* HPACK header compression support
* Cloudflare zlib
* njs module
* echo module
* more headers module
