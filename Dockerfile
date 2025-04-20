FROM ubuntu

RUN apt-get update && \
    apt-get install -y chezscheme-dev guile-3.0-dev gcc && \
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV GUILE_AUTO_COMPILE=0

WORKDIR /opt/test-runner
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
