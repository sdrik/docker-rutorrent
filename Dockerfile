ARG alpine_version=3.9

FROM alpine:${alpine_version} as builder

RUN apk add --no-cache alpine-sdk wget \
	&& adduser -G abuild -D builder \
	&& echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /home/builder
USER builder

RUN abuild-keygen -a -i
ARG alpine_version
RUN wget -r -l 0 -np -nH --cut-dirs=3 "https://git.alpinelinux.org/aports/plain/community/libtorrent/?h=$alpine_version-stable"
RUN for f in $(find libtorrent -type f); do mv $f ${f%?h=${alpine_version}-stable}; done
COPY libtorrent_enable-aligned.diff /tmp/
RUN cd libtorrent && patch -p0 < /tmp/libtorrent_enable-aligned.diff
RUN abuild-apk update
RUN cd libtorrent && abuild -r
RUN source libtorrent/APKBUILD && cp packages/builder/`apk --print-arch`/$pkgname-$pkgver-r$pkgrel.apk /tmp/$pkgname.apk

FROM linuxserver/rutorrent

COPY --from=builder /home/builder/.abuild/*.rsa.pub /etc/apk/keys/
COPY --from=builder /tmp/libtorrent.apk /tmp/
RUN apk add /tmp/libtorrent.apk && rm -f /tmp/libtorrent.apk

COPY chown_only_conf.diff /tmp/
RUN cd /etc/cont-init.d && patch -p0 < /tmp/chown_only_conf.diff && rm -f /tmp/chown_only_conf.diff
