FROM ubuntu:26.04@sha256:f3d28607ddd78734bb7f71f117f3c6706c666b8b76cbff7c9ff6e5718d46ff64

RUN apt-get update && \
    apt-get install -y chezscheme-dev guile-3.0-dev gcc && \
    apt-get purge --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV GUILE_AUTO_COMPILE=0

WORKDIR /opt/test-runner
COPY . .

ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
