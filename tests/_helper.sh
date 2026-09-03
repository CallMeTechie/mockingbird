# shellcheck shell=bash
# Shared test helpers. Sourced by every tests/run-*.sh. Plain bash, no framework.

TESTS_RUN=0
TESTS_FAILED=0

# fail <message> — record a failure and keep going, so one broken case does not
# hide the rest of the suite.
fail() {
	TESTS_FAILED=$(( TESTS_FAILED + 1 ))
	printf '  FAIL: %s\n' "$1" >&2
}

# check <label> <expected> <actual>
check() {
	TESTS_RUN=$(( TESTS_RUN + 1 ))
	if [ "$2" = "$3" ]; then
		printf '  #%d %s ... PASS\n' "$TESTS_RUN" "$1"
	else
		printf '  #%d %s ... ' "$TESTS_RUN" "$1"
		fail "expected [$2], got [$3]"
	fi
}

# check_rc <label> <expected-rc> <command...>
check_rc() {
	local label="$1" want="$2"; shift 2
	local got=0
	"$@" >/dev/null 2>&1 || got=$?
	check "$label" "$want" "$got"
}

# sandbox — mktemp -d that is removed on exit. Sets $SANDBOX.
sandbox() {
	SANDBOX="$(mktemp -d)"
	# shellcheck disable=SC2064
	trap "rm -rf -- '$SANDBOX'" EXIT
}

summary() {
	printf '\n%s: %d checks, %d failed\n' "${1:-suite}" "$TESTS_RUN" "$TESTS_FAILED"
	[ "$TESTS_FAILED" -eq 0 ]
}
