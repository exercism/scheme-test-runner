FROM alpine:3.24.3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

RUN apk add --no-cache \
        gcc \
        guile-dev \
        musl-dev && \
    # Remove link-time optimization
    rm -f \
        /usr/libexec/gcc/x86_64-alpine-linux-musl/*/lto1 \
        /usr/libexec/gcc/x86_64-alpine-linux-musl/*/lto-wrapper \
        /usr/bin/lto-dump && \
    # Remove split debug info    
    rm -f /usr/bin/dwp && \
    # Remove GCC sanitizers
    rm -f \
        /usr/lib/libasan.so* \
        /usr/lib/libtsan.so* \
        /usr/lib/libubsan.so* && \
    # Remove large static archives
    rm -f \
        /usr/lib/libguile-*.a \
        /usr/lib/libgmp.a \
        /usr/lib/libltdl.a

ENV GUILE_AUTO_COMPILE=0

WORKDIR /opt/test-runner
COPY bin/ bin/
COPY code/ code/

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
