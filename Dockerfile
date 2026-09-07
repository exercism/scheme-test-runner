FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

RUN apk add --no-cache \
        chez-scheme \
        gcc \
        guile-dev \
        musl-dev && \
    ln -s /usr/bin/chez /usr/local/bin/scheme && \
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
        /usr/lib/libchezscheme.a \
        /usr/lib/libgmp.a \
        /usr/lib/libltdl.a

ENV GUILE_AUTO_COMPILE=0

WORKDIR /opt/test-runner
COPY bin/run.sh bin/run-tests.sh bin/env.sh bin/
COPY code code/

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
