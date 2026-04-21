#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: ./switch-dev.sh [diksha|pracheer]" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
fi

case "$1" in
  diksha)
    git_name="dikshadamahe"
    git_email="dikshadamahe25@gmail.com"
    ssh_host="github-diksha"
    ;;
  pracheer)
    git_name="pracheersrivastava"
    git_email="pracheer2023@gmail.com"
    ssh_host="github-pracheer"
    ;;
  *)
    usage
    ;;
esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: current directory is not inside a git repository." >&2
  exit 1
fi

remote_url="git@${ssh_host}:dikshadamahe/pstream-android.git"

git config user.name "${git_name}"
git config user.email "${git_email}"

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "${remote_url}"
else
  git remote add origin "${remote_url}"
fi

echo "Active git identity: ${git_name} <${git_email}>"
echo "Origin remote: ${remote_url}"

