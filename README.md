# krikk Home Assistant Apps

Home Assistant apps maintained by **krikk**, licensed under the MIT License.
This repository contains the amd64-only **Termix** web application and its
internal **Apache Guacamole guacd** companion.

## Installation

1. In Home Assistant, open **Settings → Apps → App repositories**.
2. Add `https://github.com/krikk/homeassistant-apps` and select **Add**.
3. Install **Termix** and **guacd**. Start guacd before Termix.
4. Configure the options shown by each app, then start the apps.
5. Open Termix at `http://homeassistant.local:8080` (or the host and port you
   selected in the Home Assistant network UI). Termix has no ingress or panel.

The Termix app connects to guacd over the internal app network. The generated
network names are based on the first eight hexadecimal characters of the
lower-cased repository URL SHA-1: `71919c26`. Do not rename the apps: the
provided defaults are `71919c26-guacd` and `71919c26-termix`.

## Publishing GHCR packages

The GitHub Actions workflow publishes images to GHCR using `GITHUB_TOKEN`.
For each package, open the repository's **Packages** page, select the package,
then choose **Package settings → Change visibility → Public**. Make the
package public so Home Assistant can pull it without a private registry token.

## Architecture notes

Both apps declare and build only `linux/amd64`; they are not intended for ARM.
Termix is based on `ghcr.io/termix-ssh/termix:26.10.2`; guacd is based on
`guacamole/guacd:1.6.0`. The Termix image keeps its upstream entrypoint and
command behind a small wrapper that applies Home Assistant options first.

Termix data is stored at `/data` through `DATA_DIR=/data`, so its database and
keys are included in Home Assistant backups. The apps use **hot** backups so
normal backups do not require stopping the services; stop them for a manually
critical, application-level quiescent backup.
