FROM ubuntu

RUN apt-get update && \
    apt-get install -y guile-2.2 chezscheme && \
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/test-runner
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
