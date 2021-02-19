FROM ubuntu:20.04
LABEL maintainer="Domenic Mayer"
RUN groupadd -g 10000 etcdctl && useradd -u 10000 -g 10000 -s /bin/bash -m etcdctl
WORKDIR /home/etcdctl
ENV ETCD_VER=v3.4.7
ENV DOWNLOAD_URL=https://storage.googleapis.com/etcd
COPY --chown=etcdctl:etcdctl rancher-guard.bash /usr/local/bin/rancher-guard.bash
COPY --chown=etcdctl:etcdctl collect-metrics.bash /usr/local/bin/collect-metrics.bash
COPY --chown=etcdctl:etcdctl etcd-snapshooter.bash /usr/local/bin/etcd-snapshooter.bash
COPY --chown=etcdctl:etcdctl scheduler.bash /usr/local/bin/scheduler.bash
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y tzdata curl bc jq && \
    rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test && \
    curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1 && \
    rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz && \
    mv /tmp/etcd-download-test/etcdctl /usr/local/bin/etcdctl && \
    rm -rf /tmp/etcd-download-test && \
    chmod -R +x /usr/local/bin && \
    chown -R etcdctl:etcdctl /usr/local/bin && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
USER etcdctl
ENTRYPOINT ["/usr/local/bin/scheduler.bash"]