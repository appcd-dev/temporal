# syntax=docker/dockerfile:1
# Hardened temporalio/server 1.32.2.
#
# CVE-2026-4738: the scanned image is Alpine 3.24.3 with zlib 1.3.2-r1.
# The server binary is static, so it is copied from that image unchanged.
# zlib is upgraded to 1.4-r0, then the filesystem is copied onto scratch.
# Xray scans that copy, so the old zlib layer is not in the image.
# The shell and the Alpine tools stay. The process still runs as temporal (1000).

FROM temporalio/server:1.32.2@sha256:7bf69188a6232fea14869b9cef3d94aa82a1601d99517f7e86c71f22da4e0670 AS src

FROM alpine:3.24.3 AS rootfs

RUN set -eux; \
    apk -U upgrade; \
    apk add --no-cache ca-certificates tzdata; \
    apk add --no-cache --upgrade 'zlib=1.4-r0'; \
    zlib_ver="$(apk list -I zlib)"; \
    echo "${zlib_ver}"; \
    echo "${zlib_ver}" | grep -q '^zlib-1.4-r0 '; \
    echo "${zlib_ver}" | grep -q '1.3' && exit 1 || true; \
    test ! -e /usr/lib/libz.so.1.3.2; \
    test -e /usr/lib/libz.so.1.4; \
    rm -rf /var/cache/apk; \
    mkdir -p /var/cache/apk /etc/temporal; \
    addgroup -g 1000 temporal; \
    adduser -u 1000 -G temporal -D temporal

COPY --from=src --chmod=755 /usr/local/bin/temporal-server /usr/local/bin/temporal-server
COPY --from=src --chmod=755 /etc/temporal/entrypoint.sh /etc/temporal/entrypoint.sh

FROM scratch

COPY --from=rootfs / /

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /etc/temporal
USER temporal

CMD ["/etc/temporal/entrypoint.sh"]

LABEL org.opencontainers.image.title="Temporal Server" \
      org.opencontainers.image.description="Temporal Server 1.32.2 with zlib 1.4-r0" \
      org.opencontainers.image.source="https://github.com/temporalio/temporal" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.32.2"
