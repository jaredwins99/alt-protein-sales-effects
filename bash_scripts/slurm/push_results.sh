#!/usr/bin/env bash
# Send finished fits from Sherlock to GitHub. Run in ~/testing on a Sherlock login node, so that no other
# machine has to log in to Sherlock to bring them back:
#
#   bash bash_scripts/slurm/push_results.sh finalized_location1_relabel
#   DRY_RUN=1 bash bash_scripts/slurm/push_results.sh finalized_location1_relabel   # list what would be sent
#
# A generation is a folder of $SCRATCH/model_fits; it goes to model_fits/<generation> in this checkout. Sent:
# each fit folder holding summ.rds (a finished fit), the files directly in it and its plots/, and
# <generation>/_slim/, the slim draws slurm_location1_relabel.sh extracts from each fit. Never sent: fit* and
# samples* (fit.rds, the draws), and any file over 50 MB, which is listed instead.
#
# Refused: a generation that exists on origin/main (existing generations are never changed from here), a
# checkout on another branch than PUSH_BRANCH (default fix-location1-labels), a checkout with changes already
# staged, and a git that cannot tell who commits. The checkout is pulled (fast-forward only), the files are
# copied in and added by name, one commit holds them and nothing else, and it is pushed; a push refused because
# origin moved meanwhile is pulled with --rebase and tried once more. Nothing in the checkout is deleted, so
# sending a generation again commits only what is new or changed, such as fits finished meanwhile.
# Only git 1.8 commands and options (Sherlock's system git).

set -euo pipefail
BRANCH=${PUSH_BRANCH:-fix-location1-labels}
MAX_MB=50

refuse() { echo "$*; nothing sent"; exit 2; }

selected() {  # <src>: the files sent, relative to it, one a line
  (
    cd "$1"
    find . -name summ.rds -printf '%h\n' | sort -u | while read -r d; do
      find "$d" -maxdepth 1 -type f
      [ -d "$d/plots" ] && find "$d/plots" -type f
    done
    [ -d _slim ] && find _slim -type f
  ) | sed 's|^\./||' | awk -F/ '$NF !~ /^(fit|samples)/' | LC_ALL=C sort -u
}

main() {
  [ $# -eq 1 ] || refuse "name one generation: bash bash_scripts/slurm/push_results.sh finalized_location1_relabel"
  local gen=${1%/} src target big=() files=() f n
  src="$SCRATCH/model_fits/$gen"
  [ -d "$src" ] || refuse "no folder $src"
  cd "$(dirname "$(readlink -f "$0")")/../.."
  target="model_fits/$gen"
  [ "$(git rev-parse --abbrev-ref HEAD)" = "$BRANCH" ] || refuse "$(pwd) is on $(git rev-parse --abbrev-ref HEAD), not $BRANCH"
  git rev-parse -q --verify origin/main >/dev/null || refuse "origin/main is unknown here; git fetch origin first"
  [ -z "$(git ls-tree --name-only origin/main "$target")" ] || refuse "$target exists on main; existing generations are not changed from here"

  while IFS= read -r f; do
    if [ "$(stat -c %s "$src/$f")" -gt $((MAX_MB * 1024 * 1024)) ]; then big+=("$f"); else files+=("$f"); fi
  done < <(selected "$src")
  n=$(printf '%s\n' "${files[@]:-}" | awk -F/ '$NF == "summ.rds"' | wc -l)
  echo "$src -> $target: ${#files[@]} files from $n finished fits"
  [ ${#big[@]} -eq 0 ] || printf '  not sent, over %s MB: %s\n' "$MAX_MB" "${big[@]}"
  [ ${#files[@]} -gt 0 ] || { echo "nothing to send"; return 0; }

  if [ -n "${DRY_RUN:-}" ]; then
    printf '  %s\n' "${files[@]}"
    echo "dry run: nothing pulled, copied, committed or pushed"
    return 0
  fi
  git diff --cached --quiet || refuse "$(pwd) has changes staged already; commit or unstage them (git reset -q) first"
  { git var GIT_AUTHOR_IDENT && git var GIT_COMMITTER_IDENT; } >/dev/null \
    || refuse "git cannot tell who commits; set git config --global user.name and user.email first"
  git pull -q --ff-only origin "$BRANCH" \
    || refuse "git pull --ff-only failed; if an earlier push failed, git pull --rebase origin $BRANCH && git push origin $BRANCH"
  mkdir -p "$target"
  printf '%s\n' "${files[@]}" | rsync -a --files-from=- "$src/" "$target/"
  git add -- "${files[@]/#/$target/}"
  if git diff --cached --quiet; then echo "nothing new since it was last sent"; return 0; fi
  git commit -q -m "Fits of $gen from Sherlock ($n finished)"
  if ! git push -q origin "$BRANCH"; then
    echo "the push was refused; pulling origin's $BRANCH with --rebase and pushing once more"
    git pull -q --rebase origin "$BRANCH"
    git push -q origin "$BRANCH"
  fi
  echo "pushed to $BRANCH:"
  git log --oneline -n 1
  git show --stat --format= HEAD | tail -n 1
}

# on one line, so bash has read all of it before the pull, which may change this script
main "$@"; exit
