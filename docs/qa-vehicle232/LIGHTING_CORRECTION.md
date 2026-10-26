# Bigster optical correction — package 1.2.1, core 2.3.2 test

The earlier test package incorrectly placed white reversing elements inside the
upper rear cluster and illuminated only the front signature strips.

- The right rear bumper optical unit now emits white in reverse. The opposite
  lower red lens stays passive. No upper rear surfaces are reverse bindings.
- Narrow red LED rails follow the upper/lower Y arms. Broad red lenses, black
  housing and central indicator remain passive. The high-level stop lamp is
  independent of the running lights.
- Main front optical cells and signature strips both illuminate, with two
  projected headlamp beams. Front fog lamps are separate and stay unassigned.
- Added 72 LED-rail triangles; no changes to handling, route or collision data.
  The original source model and Blender checkpoint were not written.

References: supplied rear close-up/night photographs and the Dacia Bigster manual
(link in VEHICLE_FEATURES.md). The Duster photo was treated as a location analogy,
not as the Bigster optical specification. The manual's yellow overlay is a part
highlight, not the colour of the reversing light.

Inspect `lamps-forward/` and `lamps-compatibility/`: each contains 13 views,
including close running/braking/reversing/off rear states, a close Y-lens view,
front lights on/off, and independent two-car states. Intermediate experiments
were moved out of this delivery into build/vehicle232/iterations.

The focused suite now has 53 assertions, including actual driving states and
checks that the upper cluster binds only its LED rails while reverse is below
the bumper. These assertions supplement visual inspection; they alone cannot
prove photographic accuracy. Provenance and capture diagnostics are in
lighting-correction.json.
