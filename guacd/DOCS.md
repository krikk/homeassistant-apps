# guacd app documentation

This app runs Apache Guacamole's `guacd` daemon for Termix. It exposes no host
port: Termix reaches it internally at `71919c26-guacd:4822`.

The `log_level` option is passed to `guacd -L` and accepts `trace`, `debug`,
`info`, `warning`, or `error`. The app creates and shares
`/share/termix/session_recordings/guacamole` for recordings and
`/share/termix/rdp-drive` for drive redirection. Backups are hot.
