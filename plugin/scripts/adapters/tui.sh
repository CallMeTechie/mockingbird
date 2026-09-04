# shellcheck shell=bash
# tui adapter — documented only (see
# skills/verifying-against-mockup/references/adapters/tui.md), not
# implemented. Every capability reports "no" so /design-verify refuses with
# a clear "nothing was checked" MISMATCH instead of a silent, meaningless
# MATCH — see verifying-against-mockup/references/fix-policy.md and the
# "unimplemented adapter" rule in coverage-rules.md.

mb_adapter_globs() { :; }
mb_adapter_locate() { return 3; }
mb_adapter_capabilities() {
	cat <<'CAPS'
structure=no
semantic=no
states=no
tokens=no
flow=no
visual=no
runtime=no
CAPS
}
mb_adapter_token_sources() { :; }
mb_adapter_healthcheck() { :; }
