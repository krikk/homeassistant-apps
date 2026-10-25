# Changelog

## 1.6.0

- Updated upstream guacd to 1.6.0.
- Historical note: the previous updater reset the app version from
  1.6.0-1 to 1.6.0. The fixes listed below remain included.
- Initial Home Assistant app based on Apache Guacamole guacd 1.6.0.
- Added internal-only networking and shared Termix recording and drive paths.

## 1.6.0-1

- Fixed image build: the upstream image runs as a non-root user, so the
  wrapper script is now copied with --chmod and the container runs as root
  to access the Home Assistant /share and /data mappings.
- The wrapper now calls guacd by its absolute path and validates the log level.