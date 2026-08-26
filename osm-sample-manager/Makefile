# Quality gates. `make check` must pass before a pull request is ready.
PY ?= python3

.PHONY: check lint types test memory render docs docs-check integration clean

check: lint types test memory render docs-check

# ruff and mypy are pinned by PR-002. Until then, report their absence rather
# than failing the gate for a tool that is not installed yet.
lint:
	@$(PY) -c "import ruff" 2>/dev/null \
	  && $(PY) -m ruff check src tools scripts tests \
	  || echo "ruff not installed - skipping lint (pinned by PR-002)"

types:
	@$(PY) -c "import mypy" 2>/dev/null \
	  && $(PY) -m mypy \
	  || echo "mypy not installed - skipping type check (pinned by PR-002)"

test:
	$(PY) -m pytest -m "not labkey"

integration:   ## needs LK_* in the environment; see memory.md
	$(PY) -m pytest -m labkey

memory:
	$(PY) tools/memory.py check

render:
	$(PY) tools/render_backlog.py --check

# The operator guide is generated, not hand-written. Needs python-docx; report
# its absence rather than failing the gate for a tool that is not pinned yet.
docs:
	$(PY) tools/build_guide.py

docs-check:
	@$(PY) -c "import docx" 2>/dev/null \
	  && $(PY) tools/build_guide.py --check \
	  || echo "python-docx not installed - skipping docs check (pip install python-docx)"

clean:
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
	rm -rf .pytest_cache .ruff_cache .mypy_cache
