# Releasing

## Initial setup

Commit the release workflows, helper scripts and documentation to main.

The workflows require:
- Contents: write
- Packages: write
- Actions: write for dispatching the release workflow

No personal access token is required.

If main is protected, its rules must permit the release workflow to perform
a normal fast-forward push. Otherwise publication can succeed while the
final promotion to main is rejected.

Keep GHCR packages public so Home Assistant can pull them.

## Upstream updates

Run "Update upstream versions" from GitHub Actions on main.

The workflow:
1. Reads the latest stable upstream versions.
2. Does nothing when neither upstream is newer.
3. Preserves existing app revisions when upstream is unchanged.
4. Creates a unique release/upstream-... branch when updates exist.
5. Explicitly dispatches "Build and publish".

For a new upstream version, the app version starts at the upstream version,
for example 26.10.6.

## Manual app changes

Create a release/... branch from current main.

For example:
- Branch: release/termix-26.10.5-2
- App version: 26.10.5-2
- Upstream Dockerfile version: still 26.10.5

Change the app files, increment its config.yaml version and update its
CHANGELOG.md.

Push the branch. This automatically starts "Build and publish".

Alternatively, run "Build and publish" manually from main and enter the
release branch name.

Do not merge the branch into main manually before the workflow completes.

Any change inside an app directory requires a new app version if its current
version tag already exists. This deliberately includes documentation-only
changes inside that directory.

## Release process

The release workflow:
1. Pins one exact source commit.
2. Requires the release branch to contain current main.
3. Validates both app versions and image names.
4. Refuses to overwrite existing version tags.
5. Builds all missing amd64 images locally.
6. Publishes version tags only after all builds succeed.
7. Fast-forwards main to the exact source commit.
8. Updates the floating latest tags.

The workflows do not publish automatically on pushes to main.

## Failures and retries

A failed build leaves main unchanged.

If publication fails partway through, some immutable version tags may already
exist. Retry the same source commit. Tags carrying that exact source revision
are reused.

If main changes during a release, promotion stops. Merge current main into
the release branch and retry. If an earlier attempt already published an
affected app version, increment that app version before retrying the changed
commit.

If only updating latest fails after promotion, rerun the release for the same
commit.

Never delete or repoint a published version tag merely to retry a release.
Home Assistant may already be using it.

The two registry publications and the Git push are not one atomic transaction.
The ordering ensures main is not advanced before all required version tags
have been published.

Concurrency prevents overlapping releases from these workflows. Do not run
another publisher against the same version tags.

## Version history

Existing historical version tags are not rewritten by this migration.

The previous updater could reset app revisions to the upstream version.
The new updater preserves revisions unless a strictly newer upstream version
is available.