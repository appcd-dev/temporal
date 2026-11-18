# syntax=docker/dockerfile:1
# Hardened temporalio/admin-tools 1.32.2.
#
# CVE-2026-4738: the scanned image is Alpine 3.24.3 with zlib 1.3.2-r1.
# The CLI, schema tools, tdbg, and schema files are copied from that image.
# zlib is upgraded to 1.4-r0, then the filesystem is copied onto scratch.
# Xray scans that copy, so the old zlib layer is not in the image.
# The shell stays, because the schema Job and the idle command both use it.
# The process still runs as temporal (1000).

FROM temporalio/admin-tools:1.32.2@sha256:4a95866efba29d7e17ab012df5232795e8b0ad0f7d5f9d1ec4df321f7792a754 AS src

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

COPY --from=src --chmod=755 \
    /usr/local/bin/temporal \
    /usr/local/bin/temporal-cassandra-tool \
    /usr/local/bin/temporal-sql-tool \
    /usr/local/bin/temporal-elasticsearch-tool \
    /usr/local/bin/tdbg \
    /usr/local/bin/
COPY --from=src /etc/temporal/schema /etc/temporal/schema

FROM scratch

COPY --from=rootfs / /

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER temporal

CMD ["sh", "-c", "trap exit INT HUP TERM; sleep infinity & wait"]

LABEL org.opencontainers.image.title="Temporal admin tools" \
      org.opencontainers.image.description="Temporal admin-tools 1.32.2 with zlib 1.4-r0" \
      org.opencontainers.image.source="https://github.com/temporalio/temporal" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.32.2"
