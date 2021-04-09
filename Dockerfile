FROM ubuntu

RUN apt-get update && \
    apt-get install -y guile-2.2 chezscheme && \
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY scripts/run.sh /opt/test-runner/bin/run.sh
COPY scripts/exercise.ss /opt/test-runner/bin/exercise.ss
COPY example/prime-factors /mnt/alyssa-p/

WORKDIR "/opt/test-runner"
