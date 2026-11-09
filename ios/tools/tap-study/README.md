# Tap study (temporary)

Why it exists: adding a via point by tapping the route line feels hard on a phone, but
in the simulator the 30 pt tolerance works exactly as coded at every zoom. This
instrumentation records real taps from TestFlight testers so the fix can be chosen from
data. It is meant to be **deleted** afterwards: see `REMOVING.md`.

## For testers
Commutes list, top-left hand icon, "Tap study": switch on "Record taps on the route
map". Use the route editor as usual (inline and full screen, zoomed in and out). When a
tap on the line does not do what you wanted, press the hand icon at the top left of the
map ("Tap didn't work"). When done, open the same sheet and "Share data…". Nothing is
recorded while the switch is off, and nothing leaves the phone unless you share it.

## What is recorded
Screen-space numbers only: for each touch the distance (pt) from where it began to the
route line and to the nearest via handle, how far and how long the finger moved, the zoom
(metres per point), inline or full screen, and via points added / removed / moved. No
coordinates, place names or route names, and no wall-clock time.

## Reading an export
    python3 -I ios/tools/tap-study/analyze.py export1.json export2.json

| Pattern | Fix to plan next |
|---|---|
| Table 1: many taps not adding a via at 30-60 pt | Larger tolerance + snap the via onto the line |
| Table 2: many touches that began on the line never reached the tap handler | Gesture-layer fix (act on touch-down) |
| Table 3: many vias removed or moved right after being added | "Which road" problem: hold-to-add with a ghost preview + undo |
| Table 4: many retries, mostly zoomed out | Zoom-gating or a deliberate gesture |
| Table 5: flags | The ground truth: read the touches before each |

How the tables read events: `touch` = a finger went down and up on the map; `tap` = the
map's own tap handler fired (it fires for any tap, including a miss); `viaAdded` = a via
point was actually added. So a miss is a `tap` with no `viaAdded`, and a stolen touch is a
touch near the line with no `tap`.
