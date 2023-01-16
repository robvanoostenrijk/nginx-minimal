This repository is now superceded by a more enabled nginx with HTTP/3 support, which can be found [here](https://github.com/robvanoostenrijk/haproxy-http3)

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
