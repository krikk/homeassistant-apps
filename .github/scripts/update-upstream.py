#!/usr/bin/env python3

import json
import os
import re
import subprocess
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def run(*args):
    return subprocess.check_output(
        args,
        cwd=ROOT,
        text=True,
    ).strip()


def request_json(url, github=False):
    headers = {
        "Accept": "application/json",
        "User-Agent": "homeassistant-apps-updater",
    }

    if github:
        headers["Accept"] = "application/vnd.github+json"
        token = os.environ.get("GH_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(url, headers=headers)

    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def numeric_version(value):
    if not re.fullmatch(r"\d+\.\d+\.\d+", value):
        raise RuntimeError(f"Unsupported upstream version: {value!r}")

    return tuple(int(part) for part in value.split("."))


def latest_termix():
    release = request_json(
        "https://api.github.com/repos/Termix-SSH/Termix/releases/latest",
        github=True,
    )
    version = release["tag_name"].removeprefix("v")
    numeric_version(version)
    return version


def latest_guacd():
    url = (
        "https://hub.docker.com/v2/repositories/"
        "guacamole/guacd/tags?page_size=100"
    )
    versions = []

    while url:
        page = request_json(url)

        for item in page["results"]:
            name = item["name"]
            if re.fullmatch(r"\d+\.\d+\.\d+", name):
                versions.append(name)

        url = page.get("next")

        if url and not url.startswith("https://hub.docker.com/"):
            raise RuntimeError("Unexpected Docker Hub pagination URL")

    if not versions:
        raise RuntimeError("No stable guacd version found")

    return max(versions, key=numeric_version)


def update_app(app, image, latest):
    dockerfile = ROOT / app / "Dockerfile"
    config = ROOT / app / "config.yaml"
    changelog = ROOT / app / "CHANGELOG.md"

    docker_text = dockerfile.read_text()
    config_text = config.read_text()

    from_pattern = re.compile(
        rf"^FROM {re.escape(image)}:(\S+)[ \t]*$",
        re.MULTILINE,
    )
    matches = list(from_pattern.finditer(docker_text))

    if len(matches) != 1:
        raise RuntimeError(f"{dockerfile}: expected exactly one upstream FROM")

    current = matches[0].group(1)
    numeric_version(current)

    version_pattern = re.compile(
        r"^version:[ \t]*(\d+\.\d+\.\d+(?:-\d+)?)[ \t]*$",
        re.MULTILINE,
    )
    versions = list(version_pattern.finditer(config_text))

    if len(versions) != 1:
        raise RuntimeError(f"{config}: unsupported or missing app version")

    app_version = versions[0].group(1)

    if app_version.split("-", 1)[0] != current:
        raise RuntimeError(
            f"{app}: config version {app_version} does not match "
            f"Dockerfile upstream {current}"
        )

    if numeric_version(latest) <= numeric_version(current):
        print(
            f"{app}: no newer upstream version; "
            f"keeping app version {app_version}"
        )
        return False

    dockerfile.write_text(
        from_pattern.sub(
            lambda _: f"FROM {image}:{latest}",
            docker_text,
            count=1,
        )
    )
    config.write_text(
        version_pattern.sub(
            lambda _: f"version: {latest}",
            config_text,
            count=1,
        )
    )

    changelog_text = changelog.read_text()

    if not changelog_text.startswith("# Changelog\n"):
        raise RuntimeError(f"{changelog}: expected '# Changelog' heading")

    entry = (
        f"\n## {latest}\n\n"
        f"- Updated upstream {app} to {latest}.\n"
    )
    changelog.write_text(
        "# Changelog\n" + entry + changelog_text[len("# Changelog\n"):]
    )

    print(f"{app}: {app_version} -> {latest}")
    return True


def main():
    os.chdir(ROOT)

    # Resolve both versions before modifying any files.
    termix = latest_termix()
    guacd = latest_guacd()

    changed = []
    if update_app("termix", "ghcr.io/termix-ssh/termix", termix):
        changed.append("termix")
    if update_app("guacd", "guacamole/guacd", guacd):
        changed.append("guacd")

    output = Path(os.environ["GITHUB_OUTPUT"])

    if not changed:
        with output.open("a") as handle:
            handle.write("changed=false\n")
        print("Nothing to update.")
        return

    run_id = os.environ["GITHUB_RUN_ID"]
    attempt = os.environ["GITHUB_RUN_ATTEMPT"]
    branch = f"release/upstream-{run_id}-{attempt}"

    run("git", "checkout", "-b", branch)
    run("git", "config", "user.name", "github-actions[bot]")
    run(
        "git",
        "config",
        "user.email",
        "41898282+github-actions[bot]@users.noreply.github.com",
    )

    run("git", "add", "--", *changed)
    run("git", "commit", "-m", "chore: update upstream versions")
    run("git", "push", "origin", f"HEAD:refs/heads/{branch}")

    with output.open("a") as handle:
        handle.write("changed=true\n")
        handle.write(f"branch={branch}\n")

    print(f"Prepared {branch}")


if __name__ == "__main__":
    main()