#!/usr/bin/env bash
# Runs every automated suite. Plain bash, no framework.
set -u
# shellcheck disable=SC1007  # CDPATH= is a deliberate empty assignment
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
rc=0
for t in "$HERE"/run-*-tests.sh; do
	[ "$(basename "$t")" = "run-all.sh" ] && continue
	echo "### $(basename "$t")"
	bash "$t" || rc=1
	echo
done
exit "$rc"
