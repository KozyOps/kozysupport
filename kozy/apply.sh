#!/usr/bin/env bash
# Put this branch's KozySupport commits on top of an upstream RustDesk release
# tag, in the current checkout. CI runs it in every job, so a new upstream
# release builds without anyone rebasing and pushing the kozy branch first.
#
#   kozy/apply.sh 1.5.2
#
# kozy/BASE names the upstream tag the kozy branch currently sits on. After a
# manual rebase of the branch, update it in the same push.
set -euo pipefail
tag="${1:?usage: kozy/apply.sh <upstream tag>}"
base="$(cat kozy/BASE)"

git config user.name >/dev/null || git config user.name "kozysupport-ci"
git config user.email >/dev/null || git config user.email "kozysupport-ci@users.noreply.github.com"

git fetch -q --no-tags https://github.com/rustdesk/rustdesk.git \
  "+refs/tags/${base}:refs/tags/${base}" "+refs/tags/${tag}:refs/tags/${tag}"

commits="$(git rev-list --reverse "refs/tags/${base}..HEAD")"
[ -n "$commits" ] || { echo "apply: no KozySupport commits above ${base}" >&2; exit 1; }

if [ "$tag" != "$base" ]; then
  git checkout -q --detach "refs/tags/${tag}"
  # shellcheck disable=SC2086
  if ! git cherry-pick --allow-empty $commits; then
    git cherry-pick --abort || true
    echo "apply: KozySupport commits do not apply cleanly to ${tag}; rebase the kozy branch onto it by hand" >&2
    exit 1
  fi
fi
git submodule update -q --init --recursive
echo "apply: $(echo "$commits" | wc -l) KozySupport commits on ${tag}"
