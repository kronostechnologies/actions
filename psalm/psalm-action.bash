#!/bin/bash
set -e
github_action_path=$(dirname "$0")
docker_tag=$(cat ./docker_tag)
echo "Docker tag: $docker_tag" >> output.log 2>&1

command_string=(./vendor/bin/psalm --long-progress)

if [ -n "$ACTION_CONFIGURATION" ]
then
    command_string+=(--configuration="$ACTION_CONFIGURATION")
fi

if [ -n "$ACTION_MEMORY_LIMIT" ]
then
    command_string+=(--memory-limit="$ACTION_MEMORY_LIMIT")
fi

if [ -n "$ACTION_ARGS" ]
then
    command_string+=($ACTION_ARGS)
fi

if [[ "$ACTION_ONLY_CHANGED_FILES" == "yes" ]] ; then
    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    if [[ "$CURRENT_BRANCH" == "master" ]] ; then
        echo "Running psalm on all files"
    else
        # Compute changed files
        if [[ -n "${GITHUB_BASE_REF}" ]]; then
            DIFF_TARGET="origin/$GITHUB_BASE_REF..."
        else
            DIFF_TARGET="origin/master..."
        fi

        # Allow to fail early if DIFF_TARGET not found on repo
        git rev-parse $DIFF_TARGET > /dev/null 2>&1 || { echo "Diff target not found '$DIFF_TARGET'. You probably miss a git fetch step." > /dev/stderr; exit 1; }

        # Get changed files which match the pattern.
        # NOTE:
        # `|| :` is used to avoid exit by grep, when no line matches the pattern.
        CHANGED_FILES=$(git diff $DIFF_TARGET --diff-filter=AM --name-only --no-color | grep -e "\.php" || :)
        NUM_CHANGED_FILES=$(echo "$CHANGED_FILES" | grep -v -e '^\s*$' | wc -l || :)
        if [[ $NUM_CHANGED_FILES -le 0 ]] ; then
            echo "No file changes. Skip psalm."
            exit 0
        elif [[ $NUM_CHANGED_FILES -le 150 ]] ; then
            echo "Running psalm on changed files"
            echo "$CHANGED_FILES"
            command_string+=(-- $CHANGED_FILES)
        else
            echo "Running psalm on all files"
        fi
    fi
fi

echo "Command: " "${command_string[@]}" >> output.log 2>&1
docker run --rm \
    --volume "${GITHUB_WORKSPACE}":/app \
    --workdir /app \
    --network host \
    --env-file <( env| cut -f1 -d= ) \
    ${docker_tag} "${command_string[@]}"

echo "::set-output name=full_command::${command_string}"
