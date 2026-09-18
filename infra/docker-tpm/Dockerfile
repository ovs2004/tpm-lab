FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    swtpm \
    swtpm-tools \
    tpm2-tools \
    libtss2-tcti-swtpm0t64 \
    openssl \
    python3 \
    jq \
    vim-common \
    procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

COPY infra/docker-tpm/start-swtpm.sh /usr/local/bin/start-swtpm
COPY infra/docker-tpm/run-all.sh /lab/run-all.sh

RUN chmod +x \
    /usr/local/bin/start-swtpm \
    /lab/run-all.sh

ENV TPM2TOOLS_TCTI=swtpm:host=127.0.0.1,port=2321

CMD ["/bin/bash"]
