# oofzf v0.2.0 Makefile
#
# Build, verification gate, test suite, and tri-distribution packaging.
#
# Usage:
#   make build       - compile main.oo to dist/oofzf
#   make check       - run oodac check on every .oo file
#   make line-cap    - enforce 16-256 line cap on every .oo and .oot (shim-exempt)
#   make file-law    - reject forbidden file extensions and stray docs
#   make academy     - verify every .oo has the 4-element Academy header
#   make density     - enforce at most 8 pages per directory
#   make verify      - run line-cap, file-law, academy, density, and check
#   make test        - run end-to-end integration and MCP tests
#   make bench       - run performance benchmark suite
#   make package     - build deb, rpm, and arch packages
#   make clean       - remove build artifacts

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oofzf

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= 0.2.0

.PHONY: build check line-cap file-law academy density verify clean test bench package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/oofzf-linux-x86_64
	@sha256sum dist/oofzf-linux-x86_64 > dist/oofzf-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/oofzf-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="py js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		$(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== Tier 1: Core CLI Flags, Filter Mode, Empty Queries, Themes, and Options ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@./$(BIN) -h > /dev/null && echo "PASS: -h"
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@./$(BIN) -v | grep -q "0.2.0" && echo "PASS: -v"
	@./$(BIN) --help | grep -q -- "-f, --filter" && echo "PASS: --help documents -f"
	@./$(BIN) --help | grep -q -- "-q, --query" && echo "PASS: --help documents -q"
	@./$(BIN) --help | grep -q -- "-1, --select-1" && echo "PASS: --help documents -1"
	@./$(BIN) --help | grep -q -- "-0, --exit-0" && echo "PASS: --help documents -0"
	@./$(BIN) --help | grep -q -- "--no-color" && echo "PASS: --help documents --no-color"
	@./$(BIN) --help | grep -q -- "-t, --theme" && echo "PASS: --help documents -t"
	@./$(BIN) --help | grep -q -- "--mcp" && echo "PASS: --help documents --mcp"
	@printf "apple\nbanana\ncherry\napricot\n" | ./$(BIN) -f ap | grep -q "apple" && echo "PASS: filter mode"
	@printf "apple\nbanana\ncherry\napricot\n" | ./$(BIN) -fap | grep -q "apple" && echo "PASS: attached short filter flag -fap"
	@printf "apple\nbanana\ncherry\napricot\n" | ./$(BIN) --filter=ap | grep -q "apple" && echo "PASS: long filter flag --filter=ap"
	@printf "apple\nbanana\ncherry\n" | ./$(BIN) -q ban -f ban | grep -q "banana" && echo "PASS: filter query -q ban"
	@printf "apple\nbanana\ncherry\n" | ./$(BIN) -q ban -f | grep -q "banana" && echo "PASS: -q ban -f query fallback"
	@printf "apple\nbanana\ncherry\n" | ./$(BIN) -f -q ban | grep -q "banana" && echo "PASS: -f -q ban flag order"
	@printf "apple\nbanana\ncherry\n" | ./$(BIN) -qban -f ban | grep -q "banana" && echo "PASS: attached short query flag -qban"
	@printf "apple\nbanana\n" | ./$(BIN) -t1982 -f ap | grep -q "apple" && echo "PASS: attached short theme flag -t1982"
	@printf "first\nsecond\nthird\n" | ./$(BIN) -f "" | head -n1 | grep -q "first" && echo "PASS: empty query filter preserves input order"
	@printf "apple\nbanana\n" | ./$(BIN) -f ap -1 | grep -q "apple" && echo "PASS: -1 select-1 single match"
	@printf "apple\n" | ./$(BIN) -f -1 | grep -q "apple" && echo "PASS: -f -1 without positional query"
	@printf "apple\nbanana\n" | ./$(BIN) -f zzz -0 && echo "PASS: -0 exit-0 zero matches"
	@ESC=$$(printf '\033'); ! (printf "apple\n" | ./$(BIN) --no-color | grep -q "$$ESC") && echo "PASS: --no-color suppresses ANSI escapes"
	@./$(BIN) -f 0.2.0 VERSION | grep -q "0.2.0" && echo "PASS: input file positional argument"
	@echo "=== Tier 2: MCP Handshake & Protocol Framing ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "2024-11-05" && echo "PASS: MCP initialize protocolVersion"
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q '"name":"oofzf","version":"0.2.0"' && echo "PASS: MCP initialize serverInfo"
	@printf '{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP ping"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "fuzzy_match" && echo "PASS: MCP tools/list fuzzy_match"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "rank_candidates" && echo "PASS: MCP tools/list rank_candidates"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "filter_candidates" && echo "PASS: MCP tools/list filter_candidates"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "highlight_match" && echo "PASS: MCP tools/list highlight_match"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP notifications/initialized produces no response"
	@printf '{"jsonrpc":"2.0","id":4,"method":"shutdown","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":null' && echo "PASS: MCP shutdown"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"exit","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP exit terminates cleanly"
	@test "$$(printf '{"jsonrpc":"2.0","id":1,"method":"ping","params":{}}{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -c '"result":{}')" = "2" && echo "PASS: MCP concatenated JSON-RPC messages without newline"
	@printf '{"jsonrpc":"2.0","id":99,"method":"ping","params":{}}' | ./$(BIN) --mcp | grep -q '"id":99' && echo "PASS: MCP request without trailing newline"
	@(sleep 0.1 && printf '{"jsonrpc":"2.0","id":15,"method":"ping","params":{}}\n') | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP stdio idle pause does not crash server"
	@echo "=== Tier 3: All 4 MCP Tools & Execution Edge Cases ==="
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"ap","candidate":"apple"}}}\n' | ./$(BIN) --mcp | grep -q 'matched.*true' && echo "PASS: MCP fuzzy_match matched"
	@printf '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"ap","candidate":"apple"}}}\n' | ./$(BIN) --mcp | grep -q 'positions.*\[0,1\]' && echo "PASS: MCP fuzzy_match positions"
	@printf '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"xyz","candidate":"apple"}}}\n' | ./$(BIN) --mcp | grep -q 'matched.*false' && echo "PASS: MCP fuzzy_match non-match"
	@printf '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"","candidate":"apple"}}}\n' | ./$(BIN) --mcp | grep -q 'score.*:0' && echo "PASS: MCP fuzzy_match empty query score 0"
	@printf '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"query":"ap","items":"cherry\\napple\\nbanana"}}}\n' | ./$(BIN) --mcp | grep -q "apple" && echo "PASS: MCP rank_candidates newline items"
	@printf '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"query":"ap","items":["cherry","apple","banana"]}}}\n' | ./$(BIN) --mcp | grep -q "apple" && echo "PASS: MCP rank_candidates array items"
	@test "$$(printf '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"query":"a","items":["apple","apricot","avocado"],"limit":1}}}\n' | ./$(BIN) --mcp | grep -o '\\n' | wc -l)" = "1" && echo "PASS: MCP rank_candidates limit"
	@! (printf '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"query":"ap","items":["apple","banana"],"threshold":500}}}\n' | ./$(BIN) --mcp | grep -q "banana") && echo "PASS: MCP rank_candidates threshold"
	@printf '{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"filter_candidates","arguments":{"query":"ap","items":"apple\\nbanana\\napricot"}}}\n' | ./$(BIN) --mcp | grep -q "apple" && echo "PASS: MCP filter_candidates matches"
	@printf '{"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"filter_candidates","arguments":{"query":"ap","items":"apple\\nbanana\\napricot","invert":true}}}\n' | ./$(BIN) --mcp | grep -q "banana" && echo "PASS: MCP filter_candidates invert"
	@printf '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"highlight_match","arguments":{"query":"ap","candidate":"apple"}}}\n' | ./$(BIN) --mcp | grep -q '\\u001b\[' && echo "PASS: MCP highlight_match emits ANSI escapes"
	@printf '{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"highlight_match","arguments":{"query":"ap","candidate":"apple","theme":"dracula"}}}\n' | ./$(BIN) --mcp | grep -q '\\u001b\[' && echo "PASS: MCP highlight_match theme emits ANSI escapes"
	@s1=$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"apple","candidate":"apple"}}}\n' | ./$(BIN) --mcp | grep -o '"score":[0-9]*'); s2=$$(printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"apple","candidate":"Apple"}}}\n' | ./$(BIN) --mcp | grep -o '"score":[0-9]*'); test "$$s1" = "$$s2" && echo "PASS: MCP fuzzy_match case-insensitive prefix bonus equality"
	@echo "=== Tier 4: Negative Trust & Error Responses ==="
	@printf 'invalid json string\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid json exits -32600"
	@printf '{"jsonrpc":"1.0","id":30,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid jsonrpc version exits -32600"
	@printf '{"jsonrpc":"2.0","id":31,"method":"","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP empty method exits -32600"
	@printf '{"jsonrpc":"2.0","id":32,"method":"nonexistent_method","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown method exits -32601"
	@printf '{"jsonrpc":"2.0","id":33,"method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown tool exits -32601"
	@printf '{"jsonrpc":"2.0","id":34,"method":"tools/call","params":{"arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP missing tool name exits -32602"
	@printf '{"jsonrpc":"2.0","id":35,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"candidate":"apple"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP fuzzy_match missing query exits -32602"
	@printf '{"jsonrpc":"2.0","id":36,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"ap"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP fuzzy_match missing candidate exits -32602"
	@printf '{"jsonrpc":"2.0","id":37,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"query":"ap"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP rank_candidates missing items exits -32602"
	@printf '{"jsonrpc":"2.0","id":38,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"items":["apple"]}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP rank_candidates missing query exits -32602"
	@printf '{"jsonrpc":"2.0","id":39,"method":"tools/call","params":{"name":"filter_candidates","arguments":{"query":"ap"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP filter_candidates missing items exits -32602"
	@printf '{"jsonrpc":"2.0","id":40,"method":"tools/call","params":{"name":"filter_candidates","arguments":{"items":"apple"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP filter_candidates missing query exits -32602"
	@printf '{"jsonrpc":"2.0","id":41,"method":"tools/call","params":{"name":"highlight_match","arguments":{"query":"ap"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP highlight_match missing candidate exits -32602"
	@printf '{"jsonrpc":"2.0","id":42,"method":"tools/call","params":{"name":"highlight_match","arguments":{"candidate":"apple"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP highlight_match missing query exits -32602"
	@echo "=== Double-Run Determinism & Response Consistency ==="
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism tools/list Run_1 == Run_2"
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"ap","candidate":"apple"}}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"ap","candidate":"apple"}}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism fuzzy_match Run_1 == Run_2"
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"query":"ap","items":["apple","apricot","banana"]}}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"query":"ap","items":["apple","apricot","banana"]}}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism rank_candidates Run_1 == Run_2"
	@echo "=== Packaging & Installer Smoke Tests ==="
	@./install.sh --dry-run > /dev/null && echo "PASS: install.sh --dry-run"
	@./install.sh --uninstall --dry-run > /dev/null && echo "PASS: install.sh --uninstall --dry-run"
	@./uninstall.sh --dry-run > /dev/null && echo "PASS: uninstall.sh --dry-run"
	@echo "ALL TESTS PASSED"

bench: $(BIN)
	@echo "=== Running oofzf performance benchmarks ==="
	@echo "--- CLI filter benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf "apple\nbanana\ncherry\napricot\navocado\n" | ./$(BIN) -f ap > /dev/null; done'
	@echo "--- MCP fuzzy_match benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"fuzzy_match","arguments":{"query":"ap","candidate":"apple"}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP rank_candidates benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"rank_candidates","arguments":{"query":"ap","items":["apple","banana","apricot","cherry"]}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP filter_candidates benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"filter_candidates","arguments":{"query":"ap","items":"apple\\nbanana\\napricot"}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP highlight_match benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"highlight_match","arguments":{"query":"ap","candidate":"apple"}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "Benchmark complete."

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/oofzf
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/oofzf-uninstall
	@echo "installed oofzf and oofzf-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/oofzf $(DESTDIR)$(BINDIR)/oofzf-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/oofzf $(HOME)/.config/oofzf; echo "purged user cache and config"; fi
	@echo "uninstalled oofzf and oofzf-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oofzf
	@chmod 0755 dist/deb-root/usr/bin/oofzf
	@cp uninstall.sh dist/deb-root/usr/bin/oofzf-uninstall
	@chmod 0755 dist/deb-root/usr/bin/oofzf-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oofzf_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oofzf_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oofzf-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oofzf.spec > ~/rpmbuild/SPECS/oofzf.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oofzf.spec
	@cp ~/rpmbuild/RPMS/x86_64/oofzf-$(VERSION)*.rpm dist/ 2>/dev/null || true
	@if ls dist/oofzf-$(VERSION)-1.*.x86_64.rpm 1> /dev/null 2>&1; then cp dist/oofzf-$(VERSION)-1.*.x86_64.rpm dist/oofzf-$(VERSION)-1.x86_64.rpm; fi
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/oofzf
	@chmod 0755 dist/arch-pkg/usr/bin/oofzf
	@cp uninstall.sh dist/arch-pkg/usr/bin/oofzf-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/oofzf-uninstall
	@printf "pkgname = oofzf\npkgbase = oofzf\npkgver = $(VERSION)-1\npkgdesc = Sovereign interactive fuzzy finder and candidate ranker\nurl = https://github.com/openOODA-tools/oofzf\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = oofzf\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/oofzf-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD dist/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/oofzf-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cp $(BIN) dist/oofzf-linux-x86_64
	@chmod 0755 dist/oofzf-linux-x86_64
	@(cd dist && sha256sum oofzf-linux-x86_64 > oofzf-linux-x86_64.sha256)
	@(cd dist && sha256sum oofzf* > checksums.txt)
	@echo "built all packages and generated dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
