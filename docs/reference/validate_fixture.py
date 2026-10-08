#!/usr/bin/env python3
"""Validate the JSON abstract-rule fixture with a standalone Python model.

This is design-reference code. It does not execute or test Godot/GDScript,
render geometry, or establish the correctness of a production Undo system.
"""

from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
from dataclasses import dataclass, field
import json
from pathlib import Path
import sys


PALETTE = {"red", "blue", "green", "yellow", "purple", "teal"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_ids(items, label):
    ids = [item["id"] for item in items]
    require(all(isinstance(value, str) and value for value in ids),
            f"{label}: IDs must be nonempty strings")
    require(len(ids) == len(set(ids)), f"{label}: duplicate ID")
    return ids


class Fixture:
    def __init__(self, data):
        self.data = data
        require(data["schema_kind"] == "abstract_rule_fixture",
                "Input must be an abstract_rule_fixture, not a playable level")
        require(data["schema_version"] == 1, "Unsupported fixture schema")
        rules = data["rules"]
        required_rules = {
            "active_box_slots": 2, "box_capacity": 3,
            "buffer_capacity": 5, "queue_preview_count": 2,
            "matching_box_priority": "oldest_activation_then_stable_id",
            "buffer_flush": "oldest_eligible_buffered_screw_skipping_unmatched_colors",
            "replacement_order": "replace_completed_box_before_next_buffer_transfer",
            "stuck_rule": "after_settling_screws_remain_and_no_legal_exposed_move",
        }
        for key, expected in required_rules.items():
            require(rules.get(key) == expected, f"Unsupported rule: {key}")
        self.slot_count = rules["active_box_slots"]
        self.box_capacity = rules["box_capacity"]
        self.buffer_capacity = rules["buffer_capacity"]

        self.screw_order = unique_ids(data["screws"], "screws")
        self.plate_order = unique_ids(data["plates"], "plates")
        self.box_order = unique_ids(data["boxes_in_activation_order"], "boxes")
        self.screws = {s["id"]: s for s in data["screws"]}
        self.plates = {p["id"]: p for p in data["plates"]}
        self.boxes = data["boxes_in_activation_order"]
        self.box_index = {box["id"]: index for index, box in enumerate(self.boxes)}
        require(len(self.boxes) >= self.slot_count, "At least two boxes required")
        require(bool(self.screws), "Fixture must contain screws")

        owned_ids = []
        for plate in self.plates.values():
            require(type(plate["layer"]) is int, "Plate layer must be an integer")
            require(bool(plate["screw_ids"]), f"Empty plate: {plate['id']}")
            require(len(plate["screw_ids"]) == len(set(plate["screw_ids"])),
                    f"Duplicate screw on plate {plate['id']}")
            owned_ids.extend(plate["screw_ids"])
            for screw_id in plate["screw_ids"]:
                require(screw_id in self.screws, f"Unknown owned screw: {screw_id}")
                require(self.screws[screw_id]["plate_id"] == plate["id"],
                        f"Ownership disagreement for {screw_id}")
        require(Counter(owned_ids) == Counter(self.screw_order),
                "Every screw must have exactly one owner plate")

        for screw in self.screws.values():
            require(screw["color_id"] in PALETTE, "Unknown screw color")
            require(screw["plate_id"] in self.plates, "Unknown owner plate")
            blockers = screw["blocker_plate_ids"]
            require(len(blockers) == len(set(blockers)), "Duplicate blocker")
            owner = self.plates[screw["plate_id"]]
            for blocker_id in blockers:
                require(blocker_id in self.plates, "Unknown blocker plate")
                require(blocker_id != owner["id"], "A plate cannot block itself")
                require(self.plates[blocker_id]["layer"] > owner["layer"],
                        "Each blocker must have a higher logical layer")

        # Higher-layer-only edges already imply a DAG. Check it explicitly too.
        graph = {plate_id: set() for plate_id in self.plates}
        for screw in self.screws.values():
            graph[screw["plate_id"]].update(screw["blocker_plate_ids"])
        visiting, visited = set(), set()

        def visit(plate_id):
            require(plate_id not in visiting, "Plate dependency cycle")
            if plate_id in visited:
                return
            visiting.add(plate_id)
            for blocker_id in graph[plate_id]:
                visit(blocker_id)
            visiting.remove(plate_id)
            visited.add(plate_id)

        for plate_id in graph:
            visit(plate_id)

        for box in self.boxes:
            require(box["color_id"] in PALETTE, "Unknown box color")
        actual = Counter(s["color_id"] for s in self.screws.values())
        required = Counter()
        for box in self.boxes:
            required[box["color_id"]] += self.box_capacity
        require(actual == required,
                f"Per-color conservation failed: screws={actual}; boxes={required}")

    def new_box(self, index):
        definition = self.boxes[index]
        return Box(definition["id"], definition["color_id"], index)


@dataclass
class Box:
    box_id: str
    color_id: str
    activation_index: int
    screw_ids: list[str] = field(default_factory=list)


@dataclass
class State:
    remaining_screw_ids: set[str]
    active_box_slots: list[Box | None]
    next_queue_index: int
    buffer_screw_ids: list[str] = field(default_factory=list)
    completed_boxes: list[Box] = field(default_factory=list)


def initial_state(fixture):
    state = State(
        set(fixture.screw_order),
        [fixture.new_box(i) for i in range(fixture.slot_count)],
        fixture.slot_count,
    )
    audit_state(fixture, state)
    return state


def plate_removed(fixture, state, plate_id):
    return all(s not in state.remaining_screw_ids
               for s in fixture.plates[plate_id]["screw_ids"])


def exposed(fixture, state, screw_id):
    return (
        screw_id in state.remaining_screw_ids
        and all(plate_removed(fixture, state, plate_id)
                for plate_id in fixture.screws[screw_id]["blocker_plate_ids"])
    )


def matching_slot(fixture, state, color_id):
    candidates = [
        (box.activation_index, box.box_id, slot)
        for slot, box in enumerate(state.active_box_slots)
        if box is not None and box.color_id == color_id
        and len(box.screw_ids) < fixture.box_capacity
    ]
    return min(candidates)[2] if candidates else None


def legal(fixture, state, screw_id):
    if screw_id not in fixture.screws or not exposed(fixture, state, screw_id):
        return False
    return (
        matching_slot(fixture, state, fixture.screws[screw_id]["color_id"]) is not None
        or len(state.buffer_screw_ids) < fixture.buffer_capacity
    )


def settle(fixture, state):
    while True:
        full = [
            (box.activation_index, box.box_id, slot)
            for slot, box in enumerate(state.active_box_slots)
            if box is not None and len(box.screw_ids) == fixture.box_capacity
        ]
        if full:
            _, _, slot = min(full)
            state.completed_boxes.append(state.active_box_slots[slot])
            state.active_box_slots[slot] = None
            if state.next_queue_index < len(fixture.boxes):
                state.active_box_slots[slot] = fixture.new_box(state.next_queue_index)
                state.next_queue_index += 1
            continue

        # FIFO among currently eligible screws, not head-of-line blocking.
        for buffer_index, screw_id in enumerate(state.buffer_screw_ids):
            slot = matching_slot(
                fixture, state, fixture.screws[screw_id]["color_id"]
            )
            if slot is not None:
                state.active_box_slots[slot].screw_ids.append(screw_id)
                state.buffer_screw_ids.pop(buffer_index)
                break
        else:
            return


def audit_state(fixture, state):
    require(len(state.active_box_slots) == fixture.slot_count,
            "Active slot count changed")
    require(fixture.slot_count <= state.next_queue_index <= len(fixture.boxes),
            "Invalid queue cursor")
    require(len(state.buffer_screw_ids) <= fixture.buffer_capacity,
            "Buffer overflow")
    active = [box for box in state.active_box_slots if box is not None]
    if state.next_queue_index < len(fixture.boxes):
        require(len(active) == fixture.slot_count,
                "Vacant slot while an unactivated queue box remains")

    # Track actual IDs at every location. Matching color totals alone would
    # miss replacing G2 with a second G1, for example.
    all_locations = list(state.remaining_screw_ids) + state.buffer_screw_ids[:]
    for box in active + state.completed_boxes:
        all_locations.extend(box.screw_ids)
    observed = Counter(all_locations)
    expected = Counter(fixture.screw_order)
    require(observed == expected,
            "Screw ID locations have duplicates, missing IDs, or unknown IDs: "
            f"extra={dict(observed - expected)}, missing={dict(expected - observed)}")

    all_box_ids = (
        [box.box_id for box in active + state.completed_boxes]
        + fixture.box_order[state.next_queue_index:]
    )
    require(Counter(all_box_ids) == Counter(fixture.box_order),
            "Box IDs must partition active, completed, and unactivated queue")
    for box in active + state.completed_boxes:
        require(box.box_id in fixture.box_index, "Unknown box ID")
        index = fixture.box_index[box.box_id]
        require(box.activation_index == index, "Box activation index changed")
        require(box.color_id == fixture.boxes[index]["color_id"],
                "Box color changed")
        require(all(fixture.screws[s]["color_id"] == box.color_id
                    for s in box.screw_ids), "Wrong-color screw in box")
    require(all(len(box.screw_ids) == fixture.box_capacity
                for box in state.completed_boxes), "Incomplete retired box")
    require(all(len(box.screw_ids) < fixture.box_capacity for box in active),
            "State is not settled: full active box remains")
    require(all(matching_slot(fixture, state, fixture.screws[s]["color_id"]) is None
                for s in state.buffer_screw_ids),
            "State is not settled: eligible buffered screw remains")


def state_status(fixture, state):
    if not state.remaining_screw_ids:
        require(
            not state.buffer_screw_ids
            and all(box is None for box in state.active_box_slots)
            and state.next_queue_index == len(fixture.boxes),
            "Invalid settled terminal state: board empty before all boxes complete",
        )
        return "WON"
    return "ACTIVE" if any(legal(fixture, state, s) for s in fixture.screw_order) else "STUCK"


class IllegalMove(ValueError):
    pass


def apply_action(fixture, state, screw_id):
    audit_state(fixture, state)
    if not legal(fixture, state, screw_id):
        raise IllegalMove(f"Illegal screw tap: {screw_id}")
    after = deepcopy(state)
    after.remaining_screw_ids.remove(screw_id)
    slot = matching_slot(fixture, after, fixture.screws[screw_id]["color_id"])
    if slot is None:
        after.buffer_screw_ids.append(screw_id)
    else:
        after.active_box_slots[slot].screw_ids.append(screw_id)
    settle(fixture, after)
    audit_state(fixture, after)
    return after


class ReferenceSession:
    """Python reference snapshot stack; this is not a Godot Undo test."""

    def __init__(self, fixture):
        self.fixture = fixture
        self.state = initial_state(fixture)
        self.history = []

    def tap(self, screw_id):
        after = apply_action(self.fixture, self.state, screw_id)
        self.history.append(deepcopy(self.state))
        self.state = after

    def undo(self):
        if not self.history:
            return False
        self.state = deepcopy(self.history.pop())
        audit_state(self.fixture, self.state)
        return True


def box_view(box):
    if box is None:
        return None
    return {
        "box_id": box.box_id, "color_id": box.color_id,
        "activation_index": box.activation_index, "screw_ids": box.screw_ids[:],
    }


def state_view(fixture, state):
    return {
        "active_box_slots": [box_view(b) for b in state.active_box_slots],
        "buffer_screw_ids": state.buffer_screw_ids[:],
        "next_queue_index": state.next_queue_index,
        "remaining_queue_box_ids": fixture.box_order[state.next_queue_index:],
        "completed_boxes": [box_view(b) for b in state.completed_boxes],
        "remaining_screw_ids": sorted(state.remaining_screw_ids),
        "removed_plate_ids": sorted(p for p in fixture.plates if plate_removed(fixture, state, p)),
        "exposed_screw_ids": sorted(s for s in fixture.screw_order if exposed(fixture, state, s)),
        "legal_screw_ids": sorted(s for s in fixture.screw_order if legal(fixture, state, s)),
        "status": state_status(fixture, state),
    }


def check_expected(fixture, state, key):
    actual = state_view(fixture, state)
    expected = fixture.data["expected_states"][key]
    require(actual == expected,
            f"Checkpoint {key} differs.\nExpected: {json.dumps(expected)}\nActual: {json.dumps(actual)}")


def replay(fixture, actions):
    state = initial_state(fixture)
    peak = 0
    for screw_id in actions:
        state = apply_action(fixture, state, screw_id)
        peak = max(peak, len(state.buffer_screw_ids))
    return state, peak


def search_key(state):
    def box_key(box):
        if box is None:
            return None
        # Contained-ID ordering is presentation history, not a future rule.
        # Keep the actual set of contained IDs, box identity, and activation.
        return (
            box.box_id, box.color_id, box.activation_index,
            tuple(sorted(box.screw_ids)),
        )
    return (
        tuple(sorted(state.remaining_screw_ids)),
        tuple(box_key(b) for b in state.active_box_slots),
        state.next_queue_index,
        tuple(state.buffer_screw_ids),  # FIFO ID order is retained exactly.
        tuple(sorted(box_key(b) for b in state.completed_boxes)),
    )


def solve_with_buffer_limit(fixture, peak_limit, node_limit):
    visited = set()
    cutoff = False

    def dfs(state, path):
        nonlocal cutoff
        if state_status(fixture, state) == "WON":
            return path
        key = search_key(state)
        if key in visited:
            return None
        if len(visited) >= node_limit:
            cutoff = True
            return None
        visited.add(key)
        for screw_id in fixture.screw_order:
            if legal(fixture, state, screw_id):
                after = apply_action(fixture, state, screw_id)
                if len(after.buffer_screw_ids) <= peak_limit:
                    result = dfs(after, path + [screw_id])
                    if result is not None:
                        return result
        return None

    solution = dfs(initial_state(fixture), [])
    outcome = (
        "SOLVED" if solution is not None
        else "UNKNOWN_LIMIT" if cutoff
        else "UNSOLVABLE_WITH_LIMIT"
    )
    return {
        "buffer_limit": peak_limit,
        "outcome": outcome,
        "expanded_states": len(visited),
        "node_limit": node_limit,
        "exhaustive": solution is None and not cutoff,
        "budget_reached": cutoff,
        "solution": solution,
    }


def expect_rejected(fixture, session, screw_id):
    before = state_view(fixture, session.state)
    history_count = len(session.history)
    try:
        session.tap(screw_id)
    except IllegalMove:
        pass
    else:
        raise ValueError(f"Expected illegal tap was accepted: {screw_id}")
    require(state_view(fixture, session.state) == before, "Rejected tap mutated state")
    require(len(session.history) == history_count, "Rejected tap mutated history")


def validate_reference(fixture, node_limit):
    print(f"FIXTURE {fixture.data['fixture_id']}: {len(fixture.screws)} screws, "
          f"{len(fixture.plates)} plates, {len(fixture.boxes)} boxes")
    print("PASS schema, unique IDs, ownership, higher-layer DAG, and per-color inventory")

    direct = ReferenceSession(fixture)
    expect_rejected(fixture, direct, "R2")
    direct.tap("R1")
    require(direct.state.active_box_slots[0].screw_ids == ["R1"],
            "Direct matching route failed")
    require(not direct.state.buffer_screw_ids, "Direct move incorrectly buffered")
    expect_rejected(fixture, direct, "R1")
    direct.tap("G1")
    require(direct.state.buffer_screw_ids == ["G1"], "Off-color buffer route failed")
    require(exposed(fixture, direct.state, "R2"), "Cap removal did not expose R2")
    print("PASS direct route, unmatched buffer route, cap reveal, and blocked/duplicate-tap rejection")

    traces = fixture.data["traces"]
    solved, peak = replay(fixture, traces["straightforward"]["actions"])
    check_expected(fixture, solved, traces["straightforward"]["expected_final_state"])
    require(peak == traces["straightforward"]["expected_peak_buffer"],
            "Unexpected reference path peak buffer")
    print(f"PASS straightforward trace: WON, peak_buffer={peak}")

    # Deliberately preserve every color total while duplicating one same-color
    # contained ID and deleting another; the ID-location audit must reject it.
    corrupt = deepcopy(solved)
    corrupt.completed_boxes[0].screw_ids[0] = corrupt.completed_boxes[0].screw_ids[1]
    try:
        audit_state(fixture, corrupt)
    except ValueError as error:
        require("Screw ID locations" in str(error), "Unexpected corruption diagnostic")
    else:
        raise ValueError("Duplicate-ID corruption passed the audit")
    print("PASS distinct-ID location conservation; same-color duplicate/missing-ID corruption rejected")

    session = ReferenceSession(fixture)
    for screw_id in traces["fork_prefix"]["actions"]:
        session.tap(screw_id)
    check_expected(fixture, session.state, traces["fork_prefix"]["expected_final_state"])
    fork_snapshot = deepcopy(session.state)
    for screw_id in traces["wrong_fork"]["actions"]:
        session.tap(screw_id)
    check_expected(fixture, session.state, traces["wrong_fork"]["expected_final_state"])
    expect_rejected(fixture, session, "G2")
    require(session.undo(), "Reference Undo history unexpectedly empty")
    require(session.state == fork_snapshot, "Reference Undo did not restore fork snapshot")
    check_expected(fixture, session.state, "fork_prefix")
    print("PASS wrong Y3 fork: STUCK; one Python snapshot Undo restores the exact fork state")

    checkpoints = traces["recovery"]["expected_checkpoints_after_action"]
    before_cascade = None
    for index, screw_id in enumerate(traces["recovery"]["actions"], 1):
        if index == 2:
            before_cascade = deepcopy(session.state)
        session.tap(screw_id)
        if str(index) in checkpoints:
            check_expected(fixture, session.state, checkpoints[str(index)])
        if index == 1:
            require(len(session.state.buffer_screw_ids) == 5, "Expected a full buffer")
            require(state_status(fixture, session.state) == "ACTIVE", "Early full-buffer loss")
            print("PASS G2 choice: buffer=5, status=ACTIVE, legal_moves=[R3]")
        if index == 2:
            cascade_result = deepcopy(session.state)
            require(session.undo(), "Cascade reference snapshot missing")
            require(session.state == before_cascade,
                    "Reference cascade Undo did not restore the complete transaction")
            session.tap(screw_id)
            require(session.state == cascade_result,
                    "Replaying the restored cascade changed the result")
            print("PASS R3 cascade: Red and Green complete, Yellow=2/3, buffer=0")
            print("PASS Python cascade snapshot restore and replay; actual Godot Undo is not tested")
    require(state_status(fixture, session.state) == "WON", "Recovery trace did not win")
    print("PASS recovery trace: WON")

    limited = solve_with_buffer_limit(fixture, 0, 1)
    require(limited["outcome"] == "UNKNOWN_LIMIT" and not limited["exhaustive"],
            "Budget-limited search was incorrectly labeled exhaustive")
    print("PASS search budget exhaustion: UNKNOWN_LIMIT, expanded_states=1, exhaustive=false")

    minimum_spec = fixture.data["minimum_buffer_check"]
    results = []
    for limit in minimum_spec["limits_to_test"]:
        result = solve_with_buffer_limit(fixture, limit, node_limit)
        if result["outcome"] != "UNKNOWN_LIMIT":
            require(result["outcome"] == minimum_spec["expected_outcomes"][str(limit)],
                    f"Unexpected search outcome at buffer limit {limit}")
        if result["solution"] is not None:
            winning_state, winning_peak = replay(fixture, result["solution"])
            require(state_status(fixture, winning_state) == "WON" and winning_peak <= limit,
                    "Solver returned an invalid witness")
        results.append(result)
        print("SEARCH " + json.dumps(result, separators=(",", ":")))
    minimum = minimum_spec["expected_minimum_peak_buffer"]
    lower_proven = all(
        any(r["buffer_limit"] == limit and r["outcome"] == "UNSOLVABLE_WITH_LIMIT"
            and r["exhaustive"] for r in results)
        for limit in range(minimum)
    )
    witness_found = any(
        r["buffer_limit"] == minimum and r["outcome"] == "SOLVED"
        for r in results
    )
    if lower_proven and witness_found:
        print(f"MINIMUM_BUFFER_PROOF minimum={minimum}; all lower limits exhausted; "
              "scope=this abstract fixture only")
    else:
        print("MINIMUM_BUFFER_PROOF UNKNOWN: selected search budget did not establish the minimum")
    print("PASS all reference-model checks; no geometry or production Godot behavior was tested")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "fixture", nargs="?", type=Path,
        default=Path(__file__).resolve().with_name("fixture_12_screws.json"),
        help="JSON fixture path; defaults relative to this script, not the current directory",
    )
    parser.add_argument("--node-limit", type=int, default=100000,
                        help="Maximum expanded states per search, from 1 to 100000")
    args = parser.parse_args()
    require(1 <= args.node_limit <= 100000, "node-limit must be between 1 and 100000")
    data = json.loads(args.fixture.read_text(encoding="utf-8"))
    fixture = Fixture(data)
    validate_reference(fixture, args.node_limit)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, KeyError, TypeError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
