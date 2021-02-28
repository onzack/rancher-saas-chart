FROM ubuntu:20.04
LABEL maintainer="ONZACK AG"
RUN groupadd -g 10000 zack && useradd -u 10000 -g 10000 -s /bin/bash -m zack
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends tzdata curl ca-certificates webhook jq gnupg gnupg2 gnupg1 apt-transport-https bc tmux && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    curl -s https://baltocdn.com/helm/signing.asc | apt-key add - && \
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
    echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee -a /etc/apt/sources.list.d/helm-stable-debian.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends kubectl helm && \
    apt-get purge -y gnupg gnupg2 gnupg1 apt-transport-https && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
COPY --chown=zack:zack webhooks/* /etc/webhooks/
COPY --chown=zack:zack webhook-scripts/* /opt/webhook-scripts/
COPY --chown=zack:zack helm /etc/rancher-saas/helm
USER 10000
WORKDIR /home/zack
EXPOSE 9000
ENTRYPOINT ["/usr/bin/webhook"]