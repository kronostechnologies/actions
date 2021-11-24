#!/usr/bin/env bash

# This file is read by external tools. Do not move.
# Usage example in external projects:
#  curl -sSL https://raw.githubusercontent.com/kronostechnologies/standards/master/bin/gitleaks.bash | bash

set -e

BUILD_OUTPUT=build/gitleaks
CONTAINER_PATH=/repo
COMMITS_FILE=$BUILD_OUTPUT/commits.txt
OPTIONS=("--verbose" "--source=$CONTAINER_PATH")
REMOTE_CONFIG=https://raw.githubusercontent.com/kronostechnologies/standards/master/gitleaks.toml

rm -rf $BUILD_OUTPUT
mkdir -p $BUILD_OUTPUT

scan () {
    docker run --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(pwd):$CONTAINER_PATH" \
        zricethezav/gitleaks:v8.0.2 \
        "$@"
}

if [ -f "$1" ]; then
    cp -f "$1" "$BUILD_OUTPUT/gitleaks.toml"
else
    [[ -n "$1" ]] && echo "$1 is not a file"
    curl -s "$REMOTE_CONFIG" -o "$BUILD_OUTPUT/gitleaks.toml"
fi
OPTIONS+=("--config=$CONTAINER_PATH/$BUILD_OUTPUT/gitleaks.toml")

if [[ -v CI ]]; then
    OPTIONS+=("--redact")

    if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
        base_branch="origin/$GITHUB_BASE_REF"
    fi
else
    base_branch="origin/$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)"
fi

commits_count=all
if [ "$base_branch" != "" ]; then
    commits_count="$(git rev-list --count remotes/$base_branch...)"
    if [ "$commits_count" = "0" ]; then
        echo "No commits to scan. Exiting."
        exit 0
    fi

    OPTIONS+=("--log-opts=--left-right --cherry-pick --pretty=format:\"%H\" remotes/$base_branch...")
fi

echo "Scanning $commits_count commits"
scan detect --report-format sarif --report-path "$BUILD_OUTPUT/gitleaks.sarif" "${OPTIONS[@]}"
