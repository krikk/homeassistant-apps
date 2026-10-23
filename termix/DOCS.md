# Termix app documentation

## Options

- **SSL** enables HTTPS. Put `fullchain.pem` and `privkey.pem` in `/ssl`,
  or choose different filenames using `certfile` and `keyfile`.
  The SSL mapping is read-only. The app refuses to start if SSL is enabled
  and the configured files are missing or unreadable.
- **Log level** accepts `trace`, `debug`, `info`, `warn`, or `error`.
- **guacd host/port** default to `71919c26-guacd:4822`; start guacd first.
- **Environment variables** are advanced `name`/`value` pairs passed to Termix.
  They override the initial environment defaults, except for the reserved
  variables described below.

## Ports

| Container port | Purpose |
| -------------- | ------- |
| `8080/tcp` | HTTP. Only used when SSL is disabled. |
| `8443/tcp` | HTTPS. Only used when SSL is enabled. |

Configure external ports exclusively in the app's **Network** settings
in Home Assistant.

### Without SSL

By default, open:

`http://homeassistant:8080`

To use another external HTTP port, change the host-side mapping of
`8080/tcp`, for example to `9080`, and restart the app.

Then open:

`http://homeassistant:9080`

HTTPS is not available in this mode.

### With SSL

By default, open:

`https://homeassistant:8443`

To use another external HTTPS port:

1. Open the app's **Network** settings in Home Assistant.
2. Change the host-side mapping of `8443/tcp`, for example to `9443`.
3. Restart the app.

Then open:

`https://homeassistant:9443`

The internal HTTPS port remains `8443`. No internal forwarder is needed.

When SSL is enabled, the HTTP listener is disabled. There is no
HTTP-to-HTTPS redirect. Always access the app directly using HTTPS.

Only the port mapping for the active protocol is needed. The other
host-side port mapping may be disabled in Home Assistant.

The previous `ssl_port` option has been removed. If it remains in an
existing configuration, remove it. It is no longer used.

## Environment variables

Custom environment variable names must use the following format:

`[a-zA-Z_][a-zA-Z0-9_]*`

Values are passed literally; shell expressions are not evaluated.

### SSL override

`ENABLE_SSL` may override the SSL option.

Its value must be exactly `true` or `false`, written as a string in
`env_vars`.

Example:

```yaml
env_vars:
  - name: ENABLE_SSL
    value: "true"
