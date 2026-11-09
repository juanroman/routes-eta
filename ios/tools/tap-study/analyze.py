#!/usr/bin/env python3
"""Reads tap-study exports and prints the numbers behind the decision table in README.md.

    python3 -I ios/tools/tap-study/analyze.py export1.json [export2.json ...]

Standard library only. Temporary: delete with the rest of the study (see REMOVING.md).
"""

import json
import sys
from collections import defaultdict

TAP_MAX_TRAVEL = 10  # pt: a finger that moved less than this was trying to tap
TAP_MAX_DURATION = 0.5  # s
TAP_JOIN_SECONDS = 0.3  # a `tap` this close to a touch's end belongs to it
TAP_JOIN_POINTS = 3
REGRET_SECONDS = 30
RETRY_SECONDS = 3
RETRY_POINTS = 60
ZOOM_BUCKETS = [(5, "<5 m/pt (zoomed in)"), (20, "5-20 m/pt"), (80, "20-80 m/pt")]


def load(paths):
    sessions = defaultdict(list)
    radius = 30.0
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        radius = data.get("hitRadiusPt", radius)
        for event in data.get("events", []):
            sessions[(path, event["session"])].append(event)
    for events in sessions.values():
        events.sort(key=lambda e: e["time"])
    return sessions, radius


def tap_like(event):
    return (
        event["kind"] == "touch"
        and not event.get("cancelled")
        and event.get("travel") is not None
        and event["travel"] < TAP_MAX_TRAVEL
        and event.get("duration", 99) < TAP_MAX_DURATION
    )


def fired(touch, events):
    return any(
        e["kind"] == "tap"
        and abs(e["time"] - touch["time"]) <= TAP_JOIN_SECONDS
        and abs(e["x"] - touch["x"]) <= TAP_JOIN_POINTS
        and abs(e["y"] - touch["y"]) <= TAP_JOIN_POINTS
        for e in events
    )


def added_after(touch, events):
    return any(
        e["kind"] == "viaAdded" and 0 <= e["time"] - touch["time"] <= 0.5 for e in events
    )


def zoom_bucket(event):
    mpp = event.get("metresPerPoint")
    if mpp is None:
        return "unknown zoom"
    for limit, label in ZOOM_BUCKETS:
        if mpp < limit:
            return label
    return ">=80 m/pt (zoomed out)"


def near_handle(touch, radius):
    handle = touch.get("distToHandle")
    return handle is not None and handle <= radius


def histogram(sessions, radius):
    bins = [(0, 15), (15, 30), (30, 45), (45, 60), (60, 100), (100, float("inf"))]
    counts = defaultdict(lambda: [0, 0])  # bin -> [added, not added]
    for events in sessions.values():
        for touch in filter(tap_like, events):
            line = touch.get("distToLine")
            if line is None or near_handle(touch, radius) or not fired(touch, events):
                continue
            for low, high in bins:
                if low <= line < high:
                    counts[(low, high)][0 if added_after(touch, events) else 1] += 1
    print(f"1. Taps by distance from the line (app tolerance {radius:g} pt)")
    print("   distance      added  not added")
    for low, high in bins:
        added, missed = counts[(low, high)]
        label = f"{low}-{high:g} pt" if high != float("inf") else f">{low} pt"
        print(f"   {label:<12} {added:>6} {missed:>10}")


def stolen(sessions, radius):
    total = lost = cancelled = 0
    for events in sessions.values():
        for touch in events:
            line = touch.get("distToLine")
            if touch["kind"] != "touch" or line is None or line > radius:
                continue
            if near_handle(touch, radius):
                continue
            if touch.get("cancelled"):
                cancelled += 1
            elif tap_like(touch):
                total += 1
                lost += not fired(touch, events)
    print("\n2. Touches that began on the line (within tolerance) and tried to tap")
    print(f"   tap-like: {total}, never reached the tap handler: {lost}, cancelled: {cancelled}")


def regret(sessions):
    adds = undone = 0
    for events in sessions.values():
        for index, event in enumerate(events):
            if event["kind"] != "viaAdded":
                continue
            adds += 1
            undone += any(
                later["kind"] in ("viaRemoved", "viaMoved") and later["time"] - event["time"] <= REGRET_SECONDS
                for later in events[index + 1 :]
            )
    print(f"\n3. Via points added: {adds}, removed or moved within {REGRET_SECONDS}s: {undone}")


def retries(sessions, radius):
    by_zoom = defaultdict(lambda: [0, 0])  # bucket -> [failed, retried]
    for events in sessions.values():
        touches = [e for e in events if tap_like(e)]
        for index, touch in enumerate(touches):
            if added_after(touch, events) or near_handle(touch, radius):
                continue
            bucket = by_zoom[zoom_bucket(touch)]
            bucket[0] += 1
            bucket[1] += any(
                0 < later["time"] - touch["time"] <= RETRY_SECONDS
                and ((later["x"] - touch["x"]) ** 2 + (later["y"] - touch["y"]) ** 2) ** 0.5
                <= RETRY_POINTS
                for later in touches[index + 1 :]
            )
    print(f"\n4. Taps that did not add a via, and a retry within {RETRY_SECONDS}s / {RETRY_POINTS} pt")
    for _, label in ZOOM_BUCKETS + [(0, ">=80 m/pt (zoomed out)"), (0, "unknown zoom")]:
        failed, retried = by_zoom[label]
        print(f"   {label:<24} failed {failed:>4}   retried {retried:>4}")


def flags(sessions):
    print("\n5. 'Tap didn't work' presses, with the touches just before")
    count = 0
    for events in sessions.values():
        for index, event in enumerate(events):
            if event["kind"] != "flag":
                continue
            count += 1
            print(f"   flag at {event['time']}s ({event['screen']}, {zoom_bucket(event)})")
            before = [e for e in events[:index] if e["kind"] == "touch"][-3:]
            for touch in before:
                print(
                    f"     touch line={touch.get('distToLine')} handle={touch.get('distToHandle')} "
                    f"travel={touch.get('travel')} dur={touch.get('duration')} "
                    f"tap={'yes' if fired(touch, events) else 'NO'} cancelled={bool(touch.get('cancelled'))}"
                )
    if not count:
        print("   none")


def main(paths):
    if not paths:
        sys.exit(__doc__)
    sessions, radius = load(paths)
    total = sum(len(events) for events in sessions.values())
    print(f"{total} events in {len(sessions)} session(s)\n")
    histogram(sessions, radius)
    stolen(sessions, radius)
    regret(sessions)
    retries(sessions, radius)
    flags(sessions)


if __name__ == "__main__":
    main(sys.argv[1:])
