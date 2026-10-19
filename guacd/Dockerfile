FROM guacamole/guacd:1.6.0

# The upstream image runs as the unprivileged "guacd" user.
# Home Assistant maps /share and /data owned by root, so run as root.
USER root

COPY --chmod=0755 run.sh /usr/local/bin/ha-guacd-run

ENTRYPOINT ["/usr/local/bin/ha-guacd-run"]
CMD []
