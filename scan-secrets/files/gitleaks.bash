#!/usr/bin/env bash

# This file is read by external tools. Do not move.
# Usage example in external projects:
#  curl -sSL https://raw.githubusercontent.com/kronostechnologies/standards/master/bin/gitleaks.bash | bash

set -e

BUILD_OUTPUT=build/gitleaks
CONTAINER_PATH=/repo
OPTIONS=("--verbose")
REMOTE_CONFIG=https://raw.githubusercontent.com/kronostechnologies/standards/master/gitleaks.toml

rm -rf $BUILD_OUTPUT
mkdir -p $BUILD_OUTPUT

list_commits () {
    git log --left-right --cherry-pick --pretty=format:"%H" "remotes/$1..." > $BUILD_OUTPUT/commits.txt

    if ! grep -q '[^[:space:]]' $BUILD_OUTPUT/commits.txt; then
        echo "No commits to scan. Exiting."
        exit 0
    fi

    OPTIONS+=("--commits-file=$CONTAINER_PATH/$BUILD_OUTPUT/commits.txt")
}

scan () {
    docker run --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(pwd):$CONTAINER_PATH" \
        zricethezav/gitleaks:latest \
        --path="$CONTAINER_PATH" \
        "$@"
}

if [ -f "$1" ]; then
    cp -f "$1" "$BUILD_OUTPUT/gitleaks.toml"
else
    [[ -n "$1" ]] && echo "$1 is not a file"
    curl -s "$REMOTE_CONFIG" -o "$BUILD_OUTPUT/gitleaks.toml"
fi
OPTIONS+=("--additional-config=$CONTAINER_PATH/$BUILD_OUTPUT/gitleaks.toml")

if [[ -v CI ]]; then
    OPTIONS+=("--redact")

    if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
        list_commits "origin/$GITHUB_BASE_REF"
    fi
else
    echo "Scanning unstaged files"
    scan --unstaged "${OPTIONS[@]}"

    list_commits "origin/$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)"
fi

echo "Scanning commits"
scan  -f sarif -o "$BUILD_OUTPUT/gitleaks.sarif" "${OPTIONS[@]}"
