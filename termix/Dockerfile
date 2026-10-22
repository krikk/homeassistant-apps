FROM ghcr.io/termix-ssh/termix:26.10.4
USER root
RUN apt-get update && apt-get install -y --no-install-recommends jq socat && rm -rf /var/lib/apt/lists/*
COPY run.sh /usr/local/bin/ha-termix-run
RUN chmod 0755 /usr/local/bin/ha-termix-run
ENTRYPOINT ["/usr/local/bin/ha-termix-run"]
