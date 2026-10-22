# Changelog

## 26.10.2-4

- Fixed HTTPS access: with SSL enabled, Termix serves HTTPS on a separate port
  (8443) and port 8080 only redirects. Port `8443/tcp` is now published.
- Added the `ssl_port` option (default 8443) so the HTTP to HTTPS redirect
  points to the correct external port. If it differs from 8443, an internal
  forwarder maps the published port to it.
- Added `socat` to the image.

## 26.10.2-3

- Fixed startup failure "EACCES: permission denied, open '/data/.env'":
  `/data` and `/share/termix` are now handed over to the user Termix runs as
  (`PUID`/`PGID`, default 1000) on every start. Only entries with a wrong
  owner are changed.

## 26.10.2-2

- Fixed SSL "Permission denied": Termix and nginx run as an unprivileged user
  (PUID/PGID, default 1000) and could not read the root-owned files in `/ssl`.
  Certificates are now copied on startup to `/run/termix-ssl` with matching
  ownership. Keys are not written to `/data` and stay out of backups.
- `PUID`/`PGID` overrides from `env_vars` are respected for certificate
  ownership.

## 26.10.2-1

- Fixed startup failure "rm: cannot remove '/app/data': Device or resource
  busy". `/app/data` is a Docker volume in the upstream image, so it is no
  longer replaced by a symlink. Termix uses `DATA_DIR=/data` directly.
- Existing data in `/app/data` is copied once to `/data` if `/data` is empty.
- Restored `SSL_CERT_PATH` / `SSL_KEY_PATH` and added a check that the
  certificate files exist when SSL is enabled.

## 26.10.2

- Initial Home Assistant app based on Termix v26.10.2.
- Added options, SSL mapping, guacd integration, persistent data, recordings,
  and RDP-drive paths.
