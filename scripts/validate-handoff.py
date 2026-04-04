#!/usr/bin/env python3
"""KEEL Handoff Validator — structural checks on pipeline handoff files.

Usage:
    python scripts/validate-handoff.py <handoff-file-or-directory>

Examples:
    python scripts/validate-handoff.py docs/exec-plans/completed/handoffs/F13-fetch.md
    python scripts/validate-handoff.py docs/exec-plans/completed/handoffs/
    python scripts/validate-handoff.py docs/exec-plans/active/handoffs/

Exit codes:
    0 — all checks passed
    1 — one or more checks failed
    2 — usage error
"""

import re
import sys
from pathlib import Path

# --- Colors ---
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
BOLD = "\033[1m"
RESET = "\033[0m"

OK = f"{GREEN}✓{RESET}"
FAIL = f"{RED}✗{RESET}"
WARN = f"{YELLOW}!{RESET}"


# --- YAML frontmatter parsing (no dependencies) ---

def parse_frontmatter(text: str) -> dict | None:
    """Extract YAML frontmatter between --- delimiters. Returns dict or None."""
    match = re.search(r"^---\s*\n(.*?)\n---\s*$", text, re.MULTILINE | re.DOTALL)
    if not match:
        return None

    data = {}
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.split("#")[0].strip()  # strip inline comments
            data[key] = value
    return data


def extract_sections(text: str) -> dict[str, str]:
    """Extract ## sections and their content from markdown."""
    sections = {}
    current_heading = None
    current_lines = []

    for line in text.splitlines():
        heading_match = re.match(r"^## (.+)$", line)
        if heading_match:
            if current_heading is not None:
                sections[current_heading] = "\n".join(current_lines)
            current_heading = heading_match.group(1).strip()
            current_lines = []
        elif current_heading is not None:
            current_lines.append(line)

    if current_heading is not None:
        sections[current_heading] = "\n".join(current_lines)

    return sections


def section_has_content(body: str) -> bool:
    """Check if a section has real content (not just HTML comments and whitespace)."""
    stripped = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL)
    stripped = re.sub(r"###\s+\w.*", "", stripped)  # remove sub-headings
    stripped = stripped.strip()
    return len(stripped) > 0


# --- Pipeline variant definitions ---

REQUIRED_SECTIONS = {
    "bootstrap": ["landing-verifier"],
    "backend": ["pre-check", "test-writer", "implementer", "spec-reviewer", "landing-verifier"],
    "frontend": ["pre-check", "frontend-designer", "test-writer", "implementer", "spec-reviewer", "landing-verifier"],
    "cross-cutting": ["pre-check", "test-writer", "implementer", "landing-verifier"],
}

CONDITIONAL_SECTIONS = {
    "researcher_needed": "researcher",
    "designer_needed": "backend-designer / frontend-designer",
    "safety_auditor_needed": "safety-auditor",
    "arch_advisor_needed": "arch-advisor-consultation",
}

VALID_INTENTS = {"refactoring", "build", "mid-sized", "architecture", "research"}
VALID_COMPLEXITIES = {"trivial", "standard", "complex", "architecture-tier"}
VALID_YES_NO = {"YES", "NO"}
VALID_SPEC_VERDICTS = {"CONFORMANT", "DEVIATION"}
VALID_SAFETY_VERDICTS = {"PASS", "VIOLATION"}
VALID_ARCH_VERDICTS = {"SOUND", "UNSOUND"}


# --- Validator ---

class HandoffValidator:
    def __init__(self, filepath: Path):
        self.filepath = filepath
        self.text = filepath.read_text(encoding="utf-8")
        self.frontmatter = parse_frontmatter(self.text)
        self.sections = extract_sections(self.text)
        self.passed = 0
        self.failed = 0
        self.warned = 0

    def ok(self, msg: str):
        print(f"  {OK} {msg}")
        self.passed += 1

    def fail(self, msg: str):
        print(f"  {FAIL} {msg}")
        self.failed += 1

    def warn(self, msg: str):
        print(f"  {WARN} {msg}")
        self.warned += 1

    def validate(self) -> bool:
        print(f"\n{BOLD}Validating:{RESET} {self.filepath}")

        if not self._check_frontmatter():
            return False

        pipeline = self.frontmatter.get("pipeline", "")
        status = self.frontmatter.get("status", "")

        self._check_pipeline(pipeline)

        if pipeline != "bootstrap":
            self._check_routing_fields()

        self._check_required_sections(pipeline)
        self._check_conditional_sections()

        if status == "LANDED":
            self._check_verdicts()

        self._check_status_consistency(status)

        total = self.passed + self.failed
        result = "PASS" if self.failed == 0 else "FAIL"
        color = GREEN if self.failed == 0 else RED
        warnings = f" ({self.warned} warnings)" if self.warned else ""
        print(f"\n  {color}{BOLD}Result: {result}{RESET} ({self.passed}/{total} checks){warnings}\n")
        return self.failed == 0

    def _check_frontmatter(self) -> bool:
        if self.frontmatter is None:
            self.fail("No YAML frontmatter found (missing --- delimiters)")
            return False
        self.ok("YAML frontmatter found")

        if not self.frontmatter.get("status"):
            self.fail("Missing required field: status")
        if not self.frontmatter.get("pipeline"):
            self.fail("Missing required field: pipeline")

        return self.frontmatter.get("status") and self.frontmatter.get("pipeline")

    def _check_pipeline(self, pipeline: str):
        if pipeline in REQUIRED_SECTIONS:
            self.ok(f"Pipeline: {pipeline}")
        elif pipeline:
            self.fail(f"Unknown pipeline variant: {pipeline} (expected: {', '.join(REQUIRED_SECTIONS.keys())})")
        # empty already caught by _check_frontmatter

    def _check_routing_fields(self):
        fm = self.frontmatter

        intent = fm.get("intent", "")
        if intent in VALID_INTENTS:
            self.ok(f"Intent: {intent}")
        elif intent:
            self.fail(f"Invalid intent: {intent} (expected: {', '.join(sorted(VALID_INTENTS))})")
        else:
            self.fail("Missing routing field: intent")

        complexity = fm.get("complexity", "")
        if complexity in VALID_COMPLEXITIES:
            self.ok(f"Complexity: {complexity}")
        elif complexity:
            self.fail(f"Invalid complexity: {complexity} (expected: {', '.join(sorted(VALID_COMPLEXITIES))})")
        else:
            self.fail("Missing routing field: complexity")

        for flag in ["designer_needed", "researcher_needed", "safety_auditor_needed", "arch_advisor_needed"]:
            val = fm.get(flag, "")
            if val in VALID_YES_NO:
                pass  # valid, don't clutter output
            elif val:
                self.fail(f"Invalid {flag}: {val} (expected: YES or NO)")
            else:
                self.warn(f"{flag} not set")

    def _check_required_sections(self, pipeline: str):
        required = REQUIRED_SECTIONS.get(pipeline, [])
        for section_name in required:
            found = self._find_section(section_name)
            if found and section_has_content(found):
                self.ok(f"{section_name}: non-empty")
            elif found:
                self.fail(f"{section_name}: section exists but is empty")
            else:
                self.fail(f"{section_name}: section missing")

    def _check_conditional_sections(self):
        fm = self.frontmatter
        for flag, section_name in CONDITIONAL_SECTIONS.items():
            if fm.get(flag) == "YES":
                found = self._find_section(section_name)
                if found and section_has_content(found):
                    self.ok(f"{section_name}: non-empty (required by {flag})")
                elif found:
                    self.warn(f"{section_name}: section exists but empty ({flag}=YES)")
                else:
                    self.warn(f"{section_name}: section missing ({flag}=YES)")

    def _check_verdicts(self):
        fm = self.frontmatter

        spec_verdict = fm.get("spec_review_verdict", "")
        spec_attempt = fm.get("spec_review_attempt", "0")

        if spec_verdict == "CONFORMANT":
            self.ok(f"spec-reviewer verdict: CONFORMANT (attempt {spec_attempt})")
        elif spec_verdict == "DEVIATION":
            self.fail("spec-reviewer verdict: DEVIATION — cannot land with deviation")
        elif spec_verdict:
            self.fail(f"spec-reviewer verdict invalid: {spec_verdict}")
        else:
            self.fail("spec-reviewer verdict not set (status is LANDED)")

        if spec_attempt not in ("0", ""):
            try:
                n = int(spec_attempt)
                if n < 1 or n > 2:
                    self.warn(f"spec_review_attempt={n} (expected 1 or 2)")
            except ValueError:
                self.fail(f"spec_review_attempt not a number: {spec_attempt}")

        safety_needed = fm.get("safety_auditor_needed", "")
        safety_verdict = fm.get("safety_verdict", "")
        if safety_needed == "YES":
            if safety_verdict == "PASS":
                self.ok("safety-auditor verdict: PASS")
            elif safety_verdict == "VIOLATION":
                self.fail("safety-auditor verdict: VIOLATION — cannot land with violation")
            elif safety_verdict:
                self.fail(f"safety-auditor verdict invalid: {safety_verdict}")
            else:
                self.fail("safety-auditor verdict not set (needed=YES, status=LANDED)")

        arch_needed = fm.get("arch_advisor_needed", "")
        arch_verdict = fm.get("arch_advisor_verdict", "")
        if arch_needed == "YES":
            if arch_verdict == "SOUND":
                self.ok("arch-advisor verdict: SOUND")
            elif arch_verdict == "UNSOUND":
                self.fail("arch-advisor verdict: UNSOUND — cannot land with unsound")
            elif arch_verdict:
                self.fail(f"arch-advisor verdict invalid: {arch_verdict}")
            else:
                self.warn("arch-advisor verdict not set (needed=YES, status=LANDED)")

    def _check_status_consistency(self, status: str):
        pipeline = self.frontmatter.get("pipeline", "")
        required = REQUIRED_SECTIONS.get(pipeline, [])
        all_filled = all(
            self._find_section(s) and section_has_content(self._find_section(s))
            for s in required
        )

        if status == "LANDED":
            self.ok("Status: LANDED")
        elif status == "IN-PROGRESS" and all_filled:
            self.warn("Status still IN-PROGRESS but all required sections are filled")
        elif status == "IN-PROGRESS":
            self.ok("Status: IN-PROGRESS")
        elif status:
            self.warn(f"Unexpected status: {status}")

    def _find_section(self, name: str) -> str | None:
        """Find a section by name, handling the combined designer section."""
        if name in self.sections:
            return self.sections[name]
        # Handle "backend-designer / frontend-designer" combined heading
        if name in ("backend-designer", "frontend-designer", "backend-designer / frontend-designer"):
            for key in self.sections:
                if "designer" in key.lower() and key != "arch-advisor-consultation":
                    return self.sections[key]
        return None


# --- Main ---

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)

    target = Path(sys.argv[1])

    if target.is_dir():
        files = sorted(target.glob("*.md"))
        files = [f for f in files if f.name != "_TEMPLATE.md"]
        if not files:
            print(f"No handoff files found in {target}")
            sys.exit(2)
    elif target.is_file():
        files = [target]
    else:
        print(f"Not found: {target}")
        sys.exit(2)

    all_passed = True
    for f in files:
        validator = HandoffValidator(f)
        if not validator.validate():
            all_passed = False

    if len(files) > 1:
        color = GREEN if all_passed else RED
        print(f"{color}{BOLD}{'All passed' if all_passed else 'Some failed'}{RESET} ({len(files)} files)\n")

    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
