# Termix app documentation

- **SSL** enables HTTPS. Put `fullchain.pem` and `privkey.pem` in `/ssl`, or
  choose different filenames. The SSL mapping is read-only.
- **Log level** accepts `trace`, `debug`, `info`, `warn`, or `error`.
- **guacd host/port** default to `71919c26-guacd:4822`; start guacd first.
- **Environment variables** are advanced `name`/`value` pairs passed to Termix.

Termix always listens on internal port `8080` and the container port key remains
`8080/tcp`. To use a different external port, change only the host-side mapping
in the app's **Network** UI; keep the container port at `8080/tcp`.

The wrapper sets `ENABLE_SSL`, `SSL_CERT_PATH`, `SSL_KEY_PATH`, `PORT`,
`REMOTE_DESKTOP_ENGINE`, `GUACD_HOST`, `GUACD_PORT`, `GUACD_TUNNEL_HOST`,
`GUACD_RECORDING_BACKEND_PATH`, and `RDP_DRIVE_PATH`.

Termix data is `/data` via `DATA_DIR=/data`, including its database and keys.
At runtime, any existing content in a non-symlink `/app/data` is moved into
`/data`, and `/app/data` is replaced with a symlink to `/data`. Recordings are
in `/share/termix/session_recordings/guacamole`; the RDP drive is
`/share/termix/rdp-drive`. Both share paths are writable and included in Home
Assistant storage. Backups are hot by design.
