FROM debian:trixie-slim@sha256:109e2c65005bf160609e4ba6acf7783752f8502ad218e298253428690b9eaa4b

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        chezscheme-dev \
        gcc \
        guile-3.0-dev && \
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV GUILE_AUTO_COMPILE=0

WORKDIR /opt/test-runner
COPY bin/run.sh bin/run-tests.sh bin/env.sh bin/
COPY code code/

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
