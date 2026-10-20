# Termix app documentation

## Options

- **SSL** enables HTTPS. Put `fullchain.pem` and `privkey.pem` in `/ssl`, or
  choose different filenames. The SSL mapping is read-only. The app refuses to
  start if SSL is enabled and the files are missing.
- **Log level** accepts `trace`, `debug`, `info`, `warn`, or `error`.
- **guacd host/port** default to `71919c26-guacd:4822`; start guacd first.
- **Environment variables** are advanced `name`/`value` pairs passed to Termix.
  They are applied last and can override any value set by the app.

## Port

Termix always listens on internal port `8080`. To use a different external
port, change only the host-side mapping in the app's **Network** UI; keep the
container port at `8080/tcp`.

## Environment set by the app

`DATA_DIR`, `PORT`, `LOG_LEVEL`, `ENABLE_SSL`, `SSL_CERT_PATH`, `SSL_KEY_PATH`,
`REMOTE_DESKTOP_ENGINE`, `GUACD_HOST`, `GUACD_PORT`, `GUACD_TUNNEL_HOST`,
`GUACD_RECORDING_BACKEND_PATH`, and `RDP_DRIVE_PATH`.

## Data and backups

Termix data (SQLite database and keys) is stored in `/data` via
`DATA_DIR=/data` and is therefore included in Home Assistant backups. Backups
are hot, so Termix keeps running during a backup.

The upstream image declares `/app/data` as a Docker volume. It is left in place
and not used. If it contains data and `/data` is still empty, that data is
copied to `/data` once on startup.

Recordings are stored in `/share/termix/session_recordings/guacamole` and the
RDP drive in `/share/termix/rdp-drive`. These live in the Home Assistant share
folder, not in the app backup.
