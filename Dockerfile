FROM ubuntu

RUN apt-get update && \
    apt-get install -y chezscheme-dev guile-2.2 gcc && \
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV C_INCLUDE_PATH=/usr/lib/csv9.5.4/ta6le:$C_INCLUDE_DIRS

WORKDIR /opt/test-runner
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
