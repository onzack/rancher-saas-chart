FROM ubuntu:20.04
LABEL maintainer="ONZACK AG"
RUN groupadd -g 10000 appuser && useradd -u 10000 -g 10000 -s /bin/bash -m appuser
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends tzdata curl ca-certificates webhook jq gnupg gnupg2 gnupg1 apt-transport-https bc && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends kubectl  && \
    apt-get purge -y curl gnupg gnupg2 gnupg1 apt-transport-https && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
COPY --chown=appuser:appuser webhooks/* /etc/webhooks/
COPY --chown=appuser:appuser webhook-scripts/* /opt/webhook-scripts/
USER 10000
WORKDIR /home/appuser
EXPOSE 9000
ENTRYPOINT ["/usr/bin/webhook"]