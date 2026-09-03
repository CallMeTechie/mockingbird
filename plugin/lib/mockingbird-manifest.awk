# Strict-subset YAML -> TSV normalizer for docs/design/manifest.yaml.
#
# Used only when yq is unavailable (mb_manifest_to_tsv in mockingbird-manifestlib.sh
# tries yq first). Understands exactly the shape documented in
# skills/designing-frontends/references/manifest-schema.md: 2-space indent,
# block sequences of mappings for screens/elements, flow-style single-line maps
# for columns/states items, no anchors/aliases, no multi-line scalars. Anything
# that does not fit that shape inside the screens/elements structure is a parse
# error (see ERRORS at the end), never a guess: a manifest that half-parses
# would silently drop UI requirements from every check downstream.
#
# Top-level keys other than schema/project/revision/updated/design_system/
# mockups_index/tokens_css/adapters/primary_adapter/screens/allocations are
# skipped structurally without being understood (changelog, flows, retired)
# -- their presence does not error, but nothing inside them is parsed.
# allocations: items are emitted on the meta channel as
#   allocation\t<spec>\t<owns-csv>\t<consumes-csv>
#
# Output: one TSV line per element, 15 fields:
#   screen_id  screen_kind  screen_artboard  element_id  element_type
#   element_label  element_status  element_verify  element_data_source
#   semantic_means  semantic_concept  semantic_aliases  semantic_not
#   states  locator_web  deferred_reason  skip_reason  screen_uses
# A field with no value is "-", never empty (keeps `cut -f` and column-count
# checks unambiguous). A meta line for top-level scalars is written to fd 3
# as "key\tvalue" when fd 3 is available (mb_manifest_meta redirects it there).

function trim(s) {
	sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
	return s
}

function stripq(s) {
	if (length(s) >= 2) {
		if (substr(s, 1, 1) == "\"" && substr(s, length(s), 1) == "\"") return substr(s, 2, length(s) - 2)
		if (substr(s, 1, 1) == "'" && substr(s, length(s), 1) == "'") return substr(s, 2, length(s) - 2)
	}
	return s
}

function inline_list(s,    body, n, i, parts, out) {
	body = s
	sub(/^\[/, "", body); sub(/\][ \t]*$/, "", body)
	body = trim(body)
	if (body == "") return ""
	n = split(body, parts, ",")
	out = ""
	for (i = 1; i <= n; i++) {
		parts[i] = trim(parts[i])
		parts[i] = stripq(parts[i])
		out = (out == "" ? parts[i] : out "," parts[i])
	}
	return out
}

# Extract a bareword value following "<key>:" inside a flow map fragment, e.g.
# id: default  or  id: loading, copy: "..." -> "loading". Deliberately does not
# comma-split the whole line: a quoted value may itself contain a comma.
function extract_bareword(s, key,    idx, rest, val) {
	idx = index(s, key ":")
	if (idx == 0) return ""
	rest = substr(s, idx + length(key) + 1)
	sub(/^[ \t]*/, "", rest)
	val = rest
	sub(/[^A-Za-z0-9_-].*$/, "", val)
	return val
}

function nz(v) { return (v == "" ? "-" : v) }

function reset_elem() {
	elem_id = ""; elem_type = ""; elem_label = ""; elem_status = ""; elem_verify = ""
	elem_ds = ""; sa_means = ""; sa_concept = ""; sa_aliases = ""; sa_not = ""
	states = ""; loc_web = ""; elem_reason_deferred = ""; elem_reason_skip = ""
}

function reset_screen() {
	scr_id = ""; scr_kind = ""; scr_artboard = ""; scr_uses = ""
}

function reset_alloc() {
	alloc_spec = ""; alloc_owns = ""; alloc_consumes = ""
}

function emit_alloc() {
	if (alloc_spec == "") return
	if (META_FD != "") printf "allocation\t%s\t%s\t%s\n", alloc_spec, nz(alloc_owns), nz(alloc_consumes) > META_FD
	reset_alloc()
}

function emit_elem() {
	if (elem_id == "") return
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", \
		nz(scr_id), nz(scr_kind), nz(scr_artboard), \
		elem_id, nz(elem_type), nz(elem_label), nz(elem_status), nz(elem_verify), nz(elem_ds), \
		nz(sa_means), nz(sa_concept), nz(sa_aliases), nz(sa_not), nz(states), nz(loc_web), \
		nz(elem_reason_deferred), nz(elem_reason_skip), nz(scr_uses)
	reset_elem()
}

function meta(key, val) {
	if (META_FD != "") printf "%s\t%s\n", key, val > META_FD
}

function parse_error(msg) {
	printf "mockingbird-manifest.awk: parse error at line %d: %s\n", NR, msg > "/dev/stderr"
	errors++
}

function is_blank(s) {
	return (s ~ /^[ \t]*$/ || s ~ /^[ \t]*#/)
}

BEGIN {
	MODE = "top"
	errors = 0
	META_FD = (ENVIRON["MB_META_FD"] != "" ? ENVIRON["MB_META_FD"] : "")
	reset_elem(); reset_screen(); reset_alloc()
}

{
	line = $0
	sub(/\r$/, "", line)
	redo = 1
	while (redo) {
		redo = 0
		dispatch(line)
	}
}

function dispatch(l,    key, val, rest) {
	if (is_blank(l)) return

	# --- indent 0: a top-level key -------------------------------------------
	if (l ~ /^[A-Za-z_][A-Za-z0-9_]*:/) {
		if (MODE == "screen" || MODE == "elements-wait" || MODE == "element" || \
		    MODE == "semantic_anchor" || MODE == "columns-skip" || MODE == "states" || MODE == "locators") {
			emit_elem()
		}
		if (MODE == "allocations") emit_alloc()
		key = l; sub(/:.*$/, "", key)
		rest = l; sub(/^[A-Za-z_][A-Za-z0-9_]*:[ \t]*/, "", rest)
		val = trim(rest)
		if (key == "screens") {
			if (val != "") { parse_error("screens: must introduce a block, not an inline value"); MODE = "skip-block"; return }
			MODE = "screens-wait"; return
		}
		if (key == "adapters") {
			if (val != "") { parse_error("adapters: must introduce a block"); MODE = "skip-block"; return }
			MODE = "adapters"; return
		}
		if (key == "allocations") {
			if (val == "[]") { MODE = "top"; return }
			if (val != "") { parse_error("allocations: must introduce a block or be []"); MODE = "skip-block"; return }
			MODE = "allocations"; return
		}
		if (val == "" || val ~ /^[\[{]/) { MODE = "skip-block"; return }
		meta(key, stripq(val))
		MODE = "top"
		return
	}

	if (MODE == "top") { parse_error("expected a top-level key, got: " l); return }

	# --- adapters: nested one-line flow maps ---------------------------------
	if (MODE == "adapters") {
		if (l ~ /^  [A-Za-z_][A-Za-z0-9_]*:[ \t]*\{.*\}[ \t]*$/) return
		parse_error("malformed line inside adapters: block: " l)
		return
	}

	# --- allocations: "- spec:" items with owns:/consumes: inline lists ---------
	if (MODE == "allocations") {
		if (l ~ /^  - spec:/) {
			emit_alloc()
			alloc_spec = stripq(trim(substr(l, index(l, "spec:") + 5)))
			return
		}
		if (l ~ /^    (owns|consumes):/) {
			key = l; sub(/^    /, "", key); sub(/:.*$/, "", key)
			rest = l; sub(/^    (owns|consumes):[ \t]*/, "", rest)
			val = trim(rest)
			if (key == "owns") alloc_owns = inline_list(val)
			else alloc_consumes = inline_list(val)
			return
		}
		parse_error("unrecognized line inside allocations: " l)
		return
	}

	if (MODE == "skip-block") return

	# --- screens: wait for the first screen item -----------------------------
	if (MODE == "screens-wait") {
		if (l ~ /^  - id:/) {
			reset_screen()
			scr_id = trim(substr(l, index(l, "id:") + 3))
			MODE = "screen"
			return
		}
		parse_error("expected a screen item ('  - id: ...'), got: " l)
		return
	}

	# --- inside a screen -------------------------------------------------------
	if (MODE == "screen") {
		if (l ~ /^  - id:/) {
			reset_screen()
			scr_id = trim(substr(l, index(l, "id:") + 3))
			return
		}
		if (l ~ /^    [a-z_]+:/) {
			key = l; sub(/^    /, "", key); sub(/:.*$/, "", key)
			rest = l; sub(/^    [a-z_]+:[ \t]*/, "", rest)
			val = trim(rest)
			if (key == "elements") {
				if (val != "") { parse_error("elements: must introduce a block"); MODE = "skip-block"; return }
				MODE = "elements-wait"; return
			}
			if (key == "kind") scr_kind = stripq(val)
			else if (key == "artboard") scr_artboard = (val == "null" ? "" : stripq(val))
			else if (key == "uses") scr_uses = inline_list(val)
			return
		}
		parse_error("unrecognized line at screen level: " l)
		return
	}

	# --- elements: wait for the first element item -----------------------------
	if (MODE == "elements-wait") {
		if (l ~ /^      - id:/) {
			emit_elem()
			elem_id = trim(substr(l, index(l, "id:") + 3))
			MODE = "element"
			return
		}
		if (l ~ /^  - id:/) { MODE = "screen"; redo = 1; return }
		if (l ~ /^    [a-z_]+:/) { MODE = "screen"; redo = 1; return }
		parse_error("expected an element item ('      - id: ...'), got: " l)
		return
	}

	# --- inside an element -------------------------------------------------------
	if (MODE == "element") {
		if (l ~ /^      - id:/) {
			emit_elem()
			elem_id = trim(substr(l, index(l, "id:") + 3))
			return
		}
		if (l ~ /^  - id:/) { emit_elem(); MODE = "screen"; redo = 1; return }
		if (l ~ /^        [a-z_]+:/) {
			key = l; sub(/^        /, "", key); sub(/:.*$/, "", key)
			rest = l; sub(/^        [a-z_]+:[ \t]*/, "", rest)
			val = trim(rest)
			if (key == "semantic_anchor") {
				if (val != "") { parse_error("semantic_anchor: must introduce a block"); return }
				MODE = "semantic_anchor"; return
			}
			if (key == "columns") {
				if (val != "") { parse_error("columns: must introduce a block"); return }
				MODE = "columns-skip"; return
			}
			if (key == "states") {
				if (val != "") { parse_error("states: must introduce a block"); return }
				MODE = "states"; return
			}
			if (key == "locators") {
				if (val != "") { parse_error("locators: must introduce a block"); return }
				MODE = "locators"; return
			}
			if (key == "type") elem_type = stripq(val)
			else if (key == "label") elem_label = stripq(val)
			else if (key == "status") elem_status = stripq(val)
			else if (key == "verify") elem_verify = stripq(val)
			else if (key == "data_source") elem_ds = stripq(val)
			else if (key == "deferred_reason") elem_reason_deferred = stripq(val)
			else if (key == "reason") elem_reason_skip = stripq(val)
			# unknown-but-well-formed scalar keys (style_ref, ...)
			# are forward-compatible: ignored, never an error.
			return
		}
		parse_error("unrecognized line at element level: " l)
		return
	}

	# --- semantic_anchor / columns / states / locators nested blocks -----------
	if (MODE == "semantic_anchor" || MODE == "columns-skip" || MODE == "states" || MODE == "locators") {
		if (l ~ /^      - id:/ || l ~ /^  - id:/ || l ~ /^        [a-z_]+:/) { MODE = "element"; redo = 1; return }
		if (MODE == "semantic_anchor") {
			if (l ~ /^          [a-z_]+:/) {
				key = l; sub(/^          /, "", key); sub(/:.*$/, "", key)
				rest = l; sub(/^          [a-z_]+:[ \t]*/, "", rest)
				val = trim(rest)
				if (key == "means") sa_means = stripq(val)
				else if (key == "concept") sa_concept = stripq(val)
				else if (key == "aliases") sa_aliases = inline_list(val)
				else if (key == "not") sa_not = inline_list(val)
				# cardinality/unit/example/source_of_truth/empty_means: not in the
				# v0.1 element table, intentionally ignored here.
				return
			}
			parse_error("unrecognized line inside semantic_anchor: " l); return
		}
		if (MODE == "columns-skip") {
			if (l ~ /^          - \{.*\}[ \t]*$/) return
			parse_error("unrecognized line inside columns: " l); return
		}
		if (MODE == "states") {
			if (l ~ /^          - \{.*\}[ \t]*$/) {
				val = extract_bareword(l, "id")
				if (val == "") { parse_error("a states item is missing a bareword id: " l); return }
				states = (states == "" ? val : states "," val)
				return
			}
			parse_error("unrecognized line inside states: " l); return
		}
		if (MODE == "locators") {
			if (l ~ /^          [a-z_]+:/) {
				key = l; sub(/^          /, "", key); sub(/:.*$/, "", key)
				rest = l; sub(/^          [a-z_]+:[ \t]*/, "", rest)
				val = trim(rest)
				if (key == "web") loc_web = stripq(val)
				return
			}
			parse_error("unrecognized line inside locators: " l); return
		}
	}

	parse_error("unrecognized line: " l)
}

END {
	emit_elem()
	emit_alloc()
	if (errors > 0) exit 5
}
