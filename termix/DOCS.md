# Termix app documentation

## Options

- **SSL** enables HTTPS. Put `fullchain.pem` and `privkey.pem` in `/ssl`, or
  choose different filenames. The SSL mapping is read-only. The app refuses to
  start if SSL is enabled and the files are missing.
- **HTTPS port** (`ssl_port`, default `8443`) is the external port used for
  HTTPS and for the HTTP to HTTPS redirect. See "Ports" below.
- **Log level** accepts `trace`, `debug`, `info`, `warn`, or `error`.
- **guacd host/port** default to `71919c26-guacd:4822`; start guacd first.
- **Environment variables** are advanced `name`/`value` pairs passed to Termix.
  They are applied last and can override any value set by the app.

## Ports

| Container port | Purpose                                               |
| -------------- | ----------------------------------------------------- |
| `8080/tcp`     | HTTP. With SSL enabled it only redirects to HTTPS.    |
| `8443/tcp`     | HTTPS. Only used when SSL is enabled.                 |

With SSL enabled, open `https://homeassistant:8443`. Plain
`http://homeassistant:8080` redirects there. Without SSL, use
`http://homeassistant:8080` and ignore port 8443.

### Changing the external HTTPS port

Termix builds the redirect URL from `ssl_port`, so the option must match the
port you actually use from outside:

1. In the app's **Network** UI, change the host port of `8443/tcp` (for
   example to `9443`). Never change the container port.
2. Set the option **HTTPS port** to the same number (`9443`).
3. Restart the app.

If `ssl_port` differs from `8443`, the app starts a small internal forwarder
from the published container port `8443` to nginx, which then listens on
`ssl_port`. The values `8080` and the guacd port are rejected.

To change the external HTTP port, change only the host-side mapping of
`8080/tcp`; keep the container port at `8080/tcp`.

## SSL certificates

Termix and its nginx run as an unprivileged user (`PUID`/`PGID`, default
`1000`), while files in the Home Assistant `/ssl` folder are owned by root.
On every start the app therefore copies the configured certificate and key to
`/run/termix-ssl` and makes them readable for that user only. The copies are
not stored in `/data`, so private keys are not included in app backups.

After renewing a certificate (for example with the Let's Encrypt app), restart
Termix to load the new files.

## Environment set by the app

`DATA_DIR`, `PORT`, `SSL_PORT`, `LOG_LEVEL`, `ENABLE_SSL`, `SSL_CERT_PATH`,
`SSL_KEY_PATH`, `REMOTE_DESKTOP_ENGINE`, `GUACD_HOST`, `GUACD_PORT`,
`GUACD_TUNNEL_HOST`, `GUACD_RECORDING_BACKEND_PATH`, and `RDP_DRIVE_PATH`.

## Data and backups

Termix data (SQLite database and keys) is stored in `/data` via
`DATA_DIR=/data` and is therefore included in Home Assistant backups. Backups
are hot, so Termix keeps running during a backup.

Home Assistant creates `/data` and `/share` as root, but Termix runs as
`PUID`/`PGID` (default `1000`). On every start the app changes the owner of
`/data` and `/share/termix` to that user. Only entries with a wrong owner are
touched, so restarts stay fast.

The upstream image declares `/app/data` as a Docker volume. It is left in place
and not used. If it contains data and `/data` is still empty, that data is
copied to `/data` once on startup.

Recordings are stored in `/share/termix/session_recordings/guacamole` and the
RDP drive in `/share/termix/rdp-drive`. These live in the Home Assistant share
folder, not in the app backup.
