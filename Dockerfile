FROM linuxserver/rutorrent as builder

RUN apk add --no-cache alpine-sdk wget \
	&& adduser -G abuild -D builder \
	&& echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /home/builder
USER builder
ENV HOME /home/builder
COPY libtorrent_enable-aligned.diff /tmp/

RUN alpine_version=$(cat /etc/apk/repositories | grep community | sed 's,.*/alpine/v,,;s,/.*,,') \
	&& wget -r -l 0 -np -nH --cut-dirs=3 "https://git.alpinelinux.org/aports/plain/community/libtorrent/?h=${alpine_version}-stable" \
	&& for f in $(find libtorrent -type f); do mv $f ${f%?h=${alpine_version}-stable}; done \
	&& abuild-keygen -a -i \
	&& (cd libtorrent && patch -p0 < /tmp/libtorrent_enable-aligned.diff) \
	&& abuild-apk update \
	&& (cd libtorrent && abuild -r) \
	&& source libtorrent/APKBUILD \
	&& cp packages/builder/`apk --print-arch`/$pkgname-$pkgver-r$pkgrel.apk /tmp/$pkgname.apk

FROM linuxserver/rutorrent

COPY --from=builder /home/builder/.abuild/*.rsa.pub /etc/apk/keys/
COPY --from=builder /tmp/libtorrent.apk /tmp/
RUN apk add /tmp/libtorrent.apk && rm -f /tmp/libtorrent.apk

COPY chown_only_conf.diff /tmp/
RUN cd /etc/cont-init.d && patch -p0 < /tmp/chown_only_conf.diff && rm -f /tmp/chown_only_conf.diff
