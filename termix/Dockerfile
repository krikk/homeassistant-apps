FROM ghcr.io/termix-ssh/termix:26.10.5

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/*

# HTTPS mode must not expose an HTTP listener or redirect.
# Fail the build if upstream changes the expected template structure.
RUN set -eu; \
    template=/app/nginx/nginx-https.conf.template; \
    test "$(grep -c '^[[:space:]]*# BEGIN HTTP_REDIRECT_SERVER[[:space:]]*$' "$template")" -eq 1; \
    test "$(grep -c '^[[:space:]]*# END HTTP_REDIRECT_SERVER[[:space:]]*$' "$template")" -eq 1; \
    sed -i \
      '/^[[:space:]]*# BEGIN HTTP_REDIRECT_SERVER[[:space:]]*$/,/^[[:space:]]*# END HTTP_REDIRECT_SERVER[[:space:]]*$/d' \
      "$template"; \
    ! grep -q 'HTTP_REDIRECT_SERVER' "$template"; \
    ! grep -Fq 'listen ${PORT}' "$template"; \
    grep -Fq 'listen ${SSL_PORT} ssl;' "$template"

COPY run.sh /usr/local/bin/ha-termix-run

RUN chmod 0755 /usr/local/bin/ha-termix-run

ENTRYPOINT ["/usr/local/bin/ha-termix-run"]
