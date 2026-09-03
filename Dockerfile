FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

RUN apk add --no-cache \
        chez-scheme \
        gcc \
        guile-dev \
        musl-dev && \
    ln -s /usr/bin/chez /usr/local/bin/scheme

ENV GUILE_AUTO_COMPILE=0

WORKDIR /opt/test-runner
COPY bin/run.sh bin/run-tests.sh bin/env.sh bin/
COPY code code/

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
