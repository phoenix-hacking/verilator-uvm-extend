#!/usr/bin/env python3
# DESCRIPTION: Validate and summarize the UVM 2020 program evidence tracker
# SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

"""Validate tracker.yaml schema version 2 and derive its progress metrics.

The tracker deliberately stores atomic facts while this program computes all
roll-ups.  A declared roll-up is accepted only when it exactly matches the
computed value.  Percentages are rounded to one decimal place; an undefined
percentage must be represented by YAML ``null``.

Program completion uses the public capability milestones M00 through M19.
Required atomic gates are also reported as an engineering-progress diagnostic.
Issue-specific progress, when declared, is derived from the required gates in
the public milestones explicitly mapped to that issue.
The separate M0-through-M17 implementation sequence is dependency-order
metadata and is intentionally not another completion denominator here.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import yaml


SCHEMA_VERSION = 2
PERCENT_DIGITS = 1
VALID_STATUSES = frozenset(
    {
        "not_started",
        "in_progress",
        "pending",
        "blocked",
        "pass",
        "fail",
        "waived",
        "not_required",
    }
)
EXPECTED_CRITERIA = frozenset(f"C{number:02d}" for number in range(1, 22))
EXPECTED_MILESTONES = frozenset(f"M{number:02d}" for number in range(20))


class UniqueKeySafeLoader(yaml.SafeLoader):
    """Safe YAML loader that rejects duplicate mapping keys."""


def _construct_unique_mapping(
    loader: UniqueKeySafeLoader, node: yaml.MappingNode, deep: bool = False
) -> dict[Any, Any]:
    mapping: dict[Any, Any] = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise yaml.constructor.ConstructorError(
                "while constructing a mapping",
                node.start_mark,
                f"found duplicate key {key!r}",
                key_node.start_mark,
            )
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


UniqueKeySafeLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_unique_mapping
)


def _percent(numerator: int, denominator: int) -> float | None:
    if denominator == 0:
        return None
    return round(100.0 * numerator / denominator, PERCENT_DIGITS)


def _completion(complete: int, total: int) -> dict[str, int | float | None]:
    return {"complete": complete, "total": total, "percent": _percent(complete, total)}


def _corpus_counts(
    planned: int,
    implemented: int,
    executed: int,
    passed: int,
    failed: int,
    blocked: int,
) -> dict[str, int | float | None]:
    return {
        "planned": planned,
        "implemented": implemented,
        "executed": executed,
        "passed": passed,
        "failed": failed,
        "blocked": blocked,
        "execution_percent": _percent(executed, planned),
        "pass_percent": _percent(passed, executed),
        "verified_percent": _percent(passed, planned),
    }


class TrackerChecker:
    """Schema and consistency checker for one loaded tracker document."""

    def __init__(self, document: Any) -> None:
        self.document = document
        self.errors: list[str] = []
        self.atomic_ids: dict[str, str] = {}
        self.test_ids: dict[str, str] = {}
        self.evidence_complete: dict[str, bool] = {}
        self.milestone_complete: dict[str, bool] = {}
        self.computed: dict[str, Any] = {}

    def error(self, path: str, message: str) -> None:
        rendered = f"{path}: {message}"
        if rendered not in self.errors:
            self.errors.append(rendered)

    def mapping(self, value: Any, path: str) -> dict[Any, Any]:
        if not isinstance(value, dict):
            self.error(path, "expected a mapping")
            return {}
        return value

    def sequence(self, value: Any, path: str) -> list[Any]:
        if not isinstance(value, list):
            self.error(path, "expected a list")
            return []
        return value

    def status(self, value: Any, path: str) -> str | None:
        if not isinstance(value, str) or value not in VALID_STATUSES:
            allowed = ", ".join(sorted(VALID_STATUSES))
            self.error(path, f"expected one normalized status ({allowed})")
            return None
        return value

    def boolean(self, value: Any, path: str) -> bool | None:
        if not isinstance(value, bool):
            self.error(path, "expected a boolean")
            return None
        return value

    def register_atomic_id(self, identifier: Any, kind: str, path: str) -> str | None:
        if not isinstance(identifier, str) or not identifier:
            self.error(path, f"{kind} ID must be a nonempty string")
            return None
        previous = self.atomic_ids.get(identifier)
        if previous is not None:
            self.error(path, f"duplicate atomic ID {identifier!r}; first used by {previous}")
            return None
        self.atomic_ids[identifier] = kind
        return identifier

    def reference_list(
        self,
        value: Any,
        path: str,
        *,
        require_nonempty: bool = False,
        known: set[str] | frozenset[str] | None = None,
    ) -> list[str]:
        values = self.sequence(value, path)
        references: list[str] = []
        seen: set[str] = set()
        for index, reference in enumerate(values):
            ref_path = f"{path}[{index}]"
            if not isinstance(reference, str) or not reference:
                self.error(ref_path, "reference must be a nonempty string")
                continue
            if reference in seen:
                self.error(ref_path, f"duplicate reference {reference!r}")
                continue
            seen.add(reference)
            references.append(reference)
            if known is not None and reference not in known:
                self.error(ref_path, f"unknown reference {reference!r}")
        if require_nonempty and not references:
            self.error(path, "at least one reference is required")
        return references

    def check_all_status_fields(self, value: Any, path: str = "$") -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                child_path = f"{path}.{key}"
                if key in {"status", "state"}:
                    self.status(child, child_path)
                self.check_all_status_fields(child, child_path)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                self.check_all_status_fields(child, f"{path}[{index}]")

    def check_evidence(self, root: dict[Any, Any]) -> dict[str, Any]:
        evidence = self.mapping(root.get("evidence"), "$.evidence")
        result: dict[str, Any] = {}
        for raw_id, raw_record in evidence.items():
            path = f"$.evidence.{raw_id}"
            evidence_id = self.register_atomic_id(raw_id, "evidence", path)
            if evidence_id is None:
                continue
            record = self.mapping(raw_record, path)
            proofs = self.mapping(record.get("proofs"), f"{path}.proofs")
            if not proofs:
                self.error(f"{path}.proofs", "at least one proof environment is required")
            complete = 0
            total = 0
            proof_result: dict[str, Any] = {}
            for raw_environment, raw_proof in proofs.items():
                proof_path = f"{path}.proofs.{raw_environment}"
                if not isinstance(raw_environment, str) or not raw_environment:
                    self.error(proof_path, "environment ID must be a nonempty string")
                    continue
                proof = self.mapping(raw_proof, proof_path)
                required = self.boolean(proof.get("required"), f"{proof_path}.required")
                status = self.status(proof.get("status"), f"{proof_path}.status")
                refs = self.reference_list(
                    proof.get("refs", []),
                    f"{proof_path}.refs",
                    require_nonempty=status == "pass",
                )
                if required is True and status == "not_required":
                    self.error(f"{proof_path}.status", "a required proof cannot be not_required")
                if required is True:
                    total += 1
                    if status == "pass":
                        complete += 1
                proof_result[raw_environment] = {
                    "required": required,
                    "status": status,
                    "refs": refs,
                }
            is_complete = total > 0 and complete == total
            self.evidence_complete[evidence_id] = is_complete
            proof_progress = _completion(complete, total)
            if "progress" in record:
                self.compare_completion(record["progress"], f"{path}.progress", proof_progress)
            result[evidence_id] = {
                **proof_progress,
                "accepted": is_complete,
                "proofs": proof_result,
            }
        return result

    def checked_evidence_refs(self, value: Any, path: str, status: str | None) -> list[str]:
        references = self.reference_list(
            value,
            path,
            require_nonempty=status == "pass",
            known=set(self.evidence_complete),
        )
        if status == "pass":
            for reference in references:
                if not self.evidence_complete.get(reference, False):
                    self.error(path, f"pass references incomplete evidence {reference!r}")
        return references

    def compare_completion(self, value: Any, path: str, expected: dict[str, Any]) -> None:
        declared = self.mapping(value, path)
        self.compare_fields(declared, path, expected)

    def compare_fields(
        self, declared: dict[Any, Any], path: str, expected: dict[str, Any]
    ) -> None:
        expected_keys = set(expected)
        actual_keys = set(declared)
        for missing in sorted(expected_keys - actual_keys):
            self.error(f"{path}.{missing}", "missing computed field")
        for extra in sorted(actual_keys - expected_keys, key=str):
            self.error(f"{path}.{extra}", "unexpected computed field")
        for key in sorted(expected_keys):
            if key not in declared:
                continue
            actual = declared[key]
            wanted = expected[key]
            field_path = f"{path}.{key}"
            if isinstance(wanted, int) and not isinstance(wanted, bool):
                if not isinstance(actual, int) or isinstance(actual, bool):
                    self.error(field_path, f"expected integer {wanted}")
                elif actual != wanted:
                    self.error(field_path, f"declared {actual}, computed {wanted}")
            elif wanted is None:
                if actual is not None:
                    self.error(
                        field_path,
                        "declared percentage must be null because its denominator is zero",
                    )
            elif not isinstance(actual, (int, float)) or isinstance(actual, bool):
                self.error(field_path, f"expected numeric percentage {wanted}")
            elif float(actual) != wanted:
                self.error(field_path, f"declared {actual}, computed {wanted}")

    def check_milestones(self, root: dict[Any, Any]) -> dict[str, Any]:
        milestones = self.mapping(root.get("milestones"), "$.milestones")
        milestone_ids = {identifier for identifier in milestones if isinstance(identifier, str)}
        if milestone_ids != EXPECTED_MILESTONES or len(milestones) != len(EXPECTED_MILESTONES):
            missing = sorted(EXPECTED_MILESTONES - milestone_ids, key=lambda item: int(item[1:]))
            extra = sorted(milestone_ids - EXPECTED_MILESTONES)
            if missing:
                self.error("$.milestones", f"missing milestone IDs: {', '.join(missing)}")
            if extra:
                self.error("$.milestones", f"unexpected milestone IDs: {', '.join(extra)}")
        result: dict[str, Any] = {}
        exited = 0
        gates_complete = 0
        gates_total = 0
        for raw_id, raw_record in milestones.items():
            path = f"$.milestones.{raw_id}"
            if not isinstance(raw_id, str):
                self.error(path, "milestone ID must be a string")
                continue
            record = self.mapping(raw_record, path)
            status = self.status(record.get("status"), f"{path}.status")
            gates = self.mapping(record.get("gates"), f"{path}.gates")
            if not gates:
                self.error(f"{path}.gates", "at least one gate is required")
            complete = 0
            total = 0
            gate_result: dict[str, Any] = {}
            for raw_gate_id, raw_gate in gates.items():
                gate_path = f"{path}.gates.{raw_gate_id}"
                gate_id = self.register_atomic_id(raw_gate_id, "gate", gate_path)
                if gate_id is None:
                    continue
                gate = self.mapping(raw_gate, gate_path)
                required_value = gate.get("required", True)
                required = self.boolean(required_value, f"{gate_path}.required")
                gate_status = self.status(gate.get("status"), f"{gate_path}.status")
                references = self.checked_evidence_refs(
                    gate.get("evidence", []), f"{gate_path}.evidence", gate_status
                )
                if required is True:
                    total += 1
                    if gate_status == "pass":
                        complete += 1
                gate_result[gate_id] = {
                    "required": required,
                    "status": gate_status,
                    "evidence": references,
                }
            gate_progress = _completion(complete, total)
            gates_complete += complete
            gates_total += total
            is_exited = total > 0 and complete == total
            self.milestone_complete[raw_id] = is_exited
            if status == "pass" and not is_exited:
                self.error(f"{path}.status", "pass requires every required gate to pass")
            elif status != "pass" and is_exited:
                self.error(f"{path}.status", "must be pass when every required gate passes")
            if "progress" in record:
                self.compare_completion(record["progress"], f"{path}.progress", gate_progress)
            if is_exited:
                exited += 1
            result[raw_id] = {
                **gate_progress,
                "exited": is_exited,
                "gates": gate_result,
            }
        return {
            **_completion(exited, len(EXPECTED_MILESTONES)),
            "atomic_gates": _completion(gates_complete, gates_total),
            "by_id": result,
        }

    def check_program(self, root: dict[Any, Any]) -> dict[str, Any]:
        program = self.mapping(root.get("program"), "$.program")
        criteria = self.mapping(program.get("criteria"), "$.program.criteria")
        criterion_ids = {identifier for identifier in criteria if isinstance(identifier, str)}
        if criterion_ids != EXPECTED_CRITERIA or len(criteria) != len(EXPECTED_CRITERIA):
            missing = sorted(EXPECTED_CRITERIA - criterion_ids)
            extra = sorted(criterion_ids - EXPECTED_CRITERIA)
            if missing:
                self.error("$.program.criteria", f"missing criterion IDs: {', '.join(missing)}")
            if extra:
                self.error("$.program.criteria", f"unexpected criterion IDs: {', '.join(extra)}")
        result: dict[str, Any] = {}
        complete = 0
        for raw_id, raw_record in criteria.items():
            path = f"$.program.criteria.{raw_id}"
            criterion_id = self.register_atomic_id(raw_id, "criterion", path)
            if criterion_id is None:
                continue
            record = self.mapping(raw_record, path)
            status = self.status(record.get("status"), f"{path}.status")
            milestone_refs = self.reference_list(
                record.get("milestones"),
                f"{path}.milestones",
                require_nonempty=True,
                known=EXPECTED_MILESTONES,
            )
            references = self.checked_evidence_refs(
                record.get("evidence", []), f"{path}.evidence", status
            )
            if status == "pass":
                incomplete = [
                    milestone
                    for milestone in milestone_refs
                    if not self.milestone_complete.get(milestone, False)
                ]
                if incomplete:
                    self.error(
                        f"{path}.status",
                        "pass references unexited milestones: " + ", ".join(incomplete),
                    )
                complete += 1
            result[criterion_id] = {
                "status": status,
                "milestones": milestone_refs,
                "evidence": references,
            }
        progress = _completion(complete, len(EXPECTED_CRITERIA))
        if "progress" in program:
            self.compare_completion(program["progress"], "$.program.progress", progress)
        return {
            **progress,
            "by_id": result,
        }

    def check_issues(
        self, root: dict[Any, Any], milestone_result: dict[str, Any]
    ) -> dict[str, Any]:
        issues = self.mapping(root.get("issues"), "$.issues")
        result: dict[str, Any] = {}
        milestone_details = milestone_result.get("by_id", {})
        for raw_id, raw_record in issues.items():
            path = f"$.issues.{raw_id}"
            record = self.mapping(raw_record, path)
            has_mapping = "milestones" in record or "progress" in record
            if not has_mapping:
                continue
            milestone_refs = self.reference_list(
                record.get("milestones"),
                f"{path}.milestones",
                require_nonempty=True,
                known=EXPECTED_MILESTONES,
            )
            complete = sum(
                int(milestone_details.get(milestone, {}).get("complete", 0))
                for milestone in milestone_refs
            )
            total = sum(
                int(milestone_details.get(milestone, {}).get("total", 0))
                for milestone in milestone_refs
            )
            progress = _completion(complete, total)
            if "progress" not in record:
                self.error(f"{path}.progress", "missing mapped-gate progress")
            else:
                self.compare_completion(record["progress"], f"{path}.progress", progress)
            result[str(raw_id)] = {**progress, "milestones": milestone_refs}
        return result

    def check_corpus(self, root: dict[Any, Any]) -> dict[str, Any]:
        corpus = self.mapping(root.get("corpus"), "$.corpus")
        if not corpus:
            self.error("$.corpus", "at least one corpus layer is required")
        aggregate = {
            key: 0
            for key in ("planned", "implemented", "executed", "passed", "failed", "blocked")
        }
        layers: dict[str, Any] = {}
        for raw_layer_id, raw_layer in corpus.items():
            path = f"$.corpus.{raw_layer_id}"
            if not isinstance(raw_layer_id, str) or not raw_layer_id:
                self.error(path, "layer ID must be a nonempty string")
                continue
            layer = self.mapping(raw_layer, path)
            tests = self.mapping(layer.get("tests"), f"{path}.tests")
            counts = {key: 0 for key in aggregate}
            for raw_test_id, raw_test in tests.items():
                test_path = f"{path}.tests.{raw_test_id}"
                if not isinstance(raw_test_id, str) or not raw_test_id:
                    self.error(test_path, "test ID must be a nonempty string")
                    continue
                previous = self.test_ids.get(raw_test_id)
                if previous is not None:
                    self.error(
                        test_path,
                        f"duplicate test ID {raw_test_id!r}; first used in {previous}",
                    )
                    continue
                self.test_ids[raw_test_id] = raw_layer_id
                test = self.mapping(raw_test, test_path)
                implemented = self.boolean(test.get("implemented"), f"{test_path}.implemented")
                status = self.status(test.get("status"), f"{test_path}.status")
                self.checked_evidence_refs(
                    test.get("evidence", []), f"{test_path}.evidence", status
                )
                counts["planned"] += 1
                if implemented is True:
                    counts["implemented"] += 1
                if status in {"pass", "fail"}:
                    counts["executed"] += 1
                    if implemented is not True:
                        self.error(
                            f"{test_path}.implemented", f"must be true when status is {status}"
                        )
                if status == "pass":
                    counts["passed"] += 1
                elif status == "fail":
                    counts["failed"] += 1
                elif status == "blocked":
                    counts["blocked"] += 1
            metrics = _corpus_counts(**counts)
            if "progress" in layer:
                self.compare_fields(
                    self.mapping(layer["progress"], f"{path}.progress"),
                    f"{path}.progress",
                    metrics,
                )
            layers[raw_layer_id] = metrics
            for key in aggregate:
                aggregate[key] += counts[key]
        return {**_corpus_counts(**aggregate), "by_layer": layers}

    def check_lane(self, root: dict[Any, Any], evidence_result: dict[str, Any]) -> dict[str, Any]:
        lane = self.mapping(root.get("lane"), "$.lane")
        references = self.reference_list(
            lane.get("evidence"),
            "$.lane.evidence",
            require_nonempty=True,
            known=set(evidence_result),
        )
        complete = 0
        total = 0
        for reference in references:
            evidence = evidence_result.get(reference, {})
            complete += int(evidence.get("complete", 0))
            total += int(evidence.get("total", 0))
        result = _completion(complete, total)
        if "progress" in lane:
            self.compare_completion(lane["progress"], "$.lane.progress", result)
        return result

    def check_declared_progress(self, root: dict[Any, Any]) -> None:
        progress = self.mapping(root.get("progress"), "$.progress")
        expected_sections = {"program", "milestones", "gates", "corpus", "lane"}
        actual_sections = set(progress)
        for missing in sorted(expected_sections - actual_sections):
            self.error(f"$.progress.{missing}", "missing progress section")
        for extra in sorted(actual_sections - expected_sections, key=str):
            self.error(f"$.progress.{extra}", "unexpected progress section")
        for section in sorted(expected_sections & actual_sections):
            expected = (
                self.computed["milestones"]["atomic_gates"]
                if section == "gates"
                else self.computed[section]
            )
            if section in {"milestones", "program"}:
                expected = {key: expected[key] for key in ("complete", "total", "percent")}
            elif section == "corpus":
                expected = {key: value for key, value in expected.items() if key != "by_layer"}
            self.compare_fields(
                self.mapping(progress[section], f"$.progress.{section}"),
                f"$.progress.{section}",
                expected,
            )

    def check(self) -> tuple[list[str], dict[str, Any]]:
        root = self.mapping(self.document, "$")
        version = root.get("schema_version")
        if version != SCHEMA_VERSION:
            self.error("$.schema_version", f"expected {SCHEMA_VERSION}, got {version!r}")
            return self.errors, self.computed

        self.check_all_status_fields(root)
        evidence = self.check_evidence(root)
        milestones = self.check_milestones(root)
        issues = self.check_issues(root, milestones)
        program = self.check_program(root)
        corpus = self.check_corpus(root)
        lane = self.check_lane(root, evidence)
        self.computed = {
            "program": program,
            "milestones": milestones,
            "issues": issues,
            "corpus": corpus,
            "lane": lane,
            "evidence": evidence,
        }
        self.check_declared_progress(root)
        return self.errors, self.computed


def _format_text(path: Path, errors: list[str], computed: dict[str, Any]) -> str:
    lines: list[str] = []
    if errors:
        lines.append(f"tracker validation FAILED: {path}")
        lines.extend(f"- {error}" for error in errors)
    else:
        lines.append(f"tracker validation PASSED: {path}")
    if computed:
        program = computed["program"]
        milestones = computed["milestones"]
        corpus = computed["corpus"]
        lane = computed["lane"]
        issues = computed["issues"]
        lines.extend(
            [
                "computed progress:",
                f"- program: {program['complete']}/{program['total']} ({program['percent']}%)",
                f"- milestone exits: {milestones['complete']}/{milestones['total']} "
                f"({milestones['percent']}%)",
                f"- atomic gates: {milestones['atomic_gates']['complete']}/"
                f"{milestones['atomic_gates']['total']} "
                f"({milestones['atomic_gates']['percent']}%)",
                f"- lane evidence: {lane['complete']}/{lane['total']} ({lane['percent']}%)",
                f"- corpus: planned={corpus['planned']} implemented={corpus['implemented']} "
                f"executed={corpus['executed']} passed={corpus['passed']} "
                f"failed={corpus['failed']} "
                f"blocked={corpus['blocked']}",
                f"- corpus rates: execution={corpus['execution_percent']}% "
                f"pass={corpus['pass_percent']}% verified={corpus['verified_percent']}%",
            ]
        )
        for issue_id, issue in sorted(issues.items(), key=lambda item: int(item[0])):
            lines.append(
                f"- issue #{issue_id} mapped gates: {issue['complete']}/{issue['total']} "
                f"({issue['percent']}%)"
            )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    default_tracker = Path(__file__).with_name("tracker.yaml")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tracker", nargs="?", type=Path, default=default_tracker)
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args(argv)

    try:
        with args.tracker.open(encoding="utf-8") as handle:
            document = yaml.load(handle, Loader=UniqueKeySafeLoader)
    except (OSError, yaml.YAMLError) as error:
        errors = [f"$: unable to load tracker: {error}"]
        computed: dict[str, Any] = {}
    else:
        errors, computed = TrackerChecker(document).check()

    if args.format == "json":
        print(
            json.dumps(
                {
                    "ok": not errors,
                    "path": str(args.tracker),
                    "errors": errors,
                    "computed": computed,
                },
                indent=2,
                sort_keys=True,
            )
        )
    else:
        print(_format_text(args.tracker, errors, computed))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
