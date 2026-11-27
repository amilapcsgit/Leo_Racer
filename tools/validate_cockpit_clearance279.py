"""Conservative continuous clearance proof from the actual compiled cabin.

Each wheel triangle's complete rotation is enclosed by radial/axial intervals.
Their union is conservatively binned into 2.5 mm annular bands about the shaft.
For each fixed triangle, independent radial and axial interval minima give a
LOWER bound on distance. A bound >=15 mm therefore proves clearance at every
angle, not just captured discrete poses. Hub depth is never misrepresented as
the depth of the entire rim, as it would be with a single bounding cylinder.
An inconclusive bound fails; it is never presented as a mesh intersection.
Run with the bundled Blender Python, which includes numpy.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sys
import numpy as np


def projected_distance(triangles):
    """Distance from the origin to each closed 2D triangle, including edges."""
    distances = []
    crosses = []
    for index in range(3):
        start = triangles[:, index]
        end = triangles[:, (index + 1) % 3]
        edge = end - start
        ratio = np.clip(-np.einsum("ij,ij->i", start, edge) / np.maximum(1e-30, np.einsum("ij,ij->i", edge, edge)), 0, 1)
        nearest = start + edge * ratio[:, None]
        distances.append(np.linalg.norm(nearest, axis=1))
        crosses.append(start[:, 0] * end[:, 1] - start[:, 1] * end[:, 0])
    crosses = np.asarray(crosses)
    twice_area = np.sum(crosses, axis=0)
    inside = ((crosses >= -1e-12).all(axis=0) | (crosses <= 1e-12).all(axis=0)) & (np.abs(twice_area) > 1e-15)
    return np.where(inside, 0., np.min(distances, axis=0))


def validate(path, additional_offset_z=0.):
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    offset = np.array([0., 0., additional_offset_z])
    hub = np.asarray(data["hub"], dtype=float) + offset
    axis = np.asarray(data["axis"], dtype=float)
    axis /= np.linalg.norm(axis)
    tangent = np.cross(axis, [1., 0., 0.])
    if np.linalg.norm(tangent) < .1: tangent = np.cross(axis, [0., 1., 0.])
    tangent /= np.linalg.norm(tangent)
    second = np.cross(axis, tangent)
    wheel = np.asarray(data["wheel_vertices"], dtype=float) + offset - hub
    depth = wheel @ axis
    radial = np.stack((wheel @ tangent, wheel @ second), axis=-1)
    radius = float(np.linalg.norm(radial, axis=1).max())
    back, front = float(depth.min()), float(depth.max())
    points = np.asarray(data["vertices"], dtype=float) - hub
    triangles = points[np.asarray(data["faces"], dtype=int)]
    projected = np.stack((triangles @ tangent, triangles @ second), axis=-1)
    fixed_min = projected_distance(projected)
    fixed_max = np.linalg.norm(projected, axis=-1).max(axis=1)
    axial = triangles @ axis
    wheel_triangles = wheel[np.asarray(data["wheel_faces"], dtype=int)]
    wheel_projection = np.stack((wheel_triangles @ tangent, wheel_triangles @ second), axis=-1)
    wheel_min = projected_distance(wheel_projection)
    wheel_max = np.linalg.norm(wheel_projection, axis=-1).max(axis=1)
    wheel_depth = wheel_triangles @ axis
    lower_bound = np.full(len(triangles), np.inf)
    bands = []
    for low in np.arange(0., radius, .0025):
        high = min(radius, low + .0025)
        occupied = (wheel_min <= high) & (wheel_max >= low)
        if not occupied.any(): continue
        rear = float(wheel_depth[occupied].min())
        ahead = float(wheel_depth[occupied].max())
        radial_gap = np.maximum(0., np.maximum(low - fixed_max, fixed_min - high))
        axial_gap = np.maximum(0., np.maximum(rear - axial.max(axis=1), axial.min(axis=1) - ahead))
        lower_bound = np.minimum(lower_bound, np.hypot(radial_gap, axial_gap))
        bands.append([float(low), float(high), rear, ahead])
    scale_bound = float(np.linalg.svd(np.asarray(data["normalization_basis"], dtype=float), compute_uv=False).min()) if "normalization_basis" in data else float(data["normalization_scale"])
    lower_bound *= scale_bound
    groups = {}
    for label, bound in zip(data["labels"], lower_bound):
        groups[label] = min(groups.get(label, float("inf")), float(bound))
    minimum = float(lower_bound.min())
    return {
        "vehicle": data["id"], "status": "PASS" if minimum >= .015 else "INCONCLUSIVE",
        "minimum_required_m": .015, "certified_clearance_lower_bound_m": minimum,
        "method": "Continuous all-angle annular-band superset; exact projected triangle radial bounds, conservative triangle axial bounds",
        "wheel_envelope": {"radius_m": radius, "axial_back_m": back, "axial_front_m": front},
        "radial_band_width_m": .0025, "radial_bands": len(bands),
        "fixed_triangles": len(triangles), "wheel_triangles": len(data["wheel_faces"]),
        "nearest_fixed_meshes": dict(sorted(groups.items(), key=lambda row: row[1])[:10]),
        "source": path.name,
        "geometry_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "diagnostic_additional_offset_z_m": additional_offset_z,
    }


def self_check():
    tri = np.array([[[-1., -1.], [1., -1.], [0., 1.]], [[1., -1.], [1., 1.], [2., 0.]], [[2., 0.], [2., 0.], [2., 0.]]])
    assert np.allclose(projected_distance(tri), [0., 1., 2.]), "Projected triangle distance failed reference cases"


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    parser.add_argument("--update-manifests", action="store_true", help="Record passing actual-geometry results in the additive pack reports")
    args = parser.parse_args()
    self_check()
    paths = sorted(args.folder.glob("geometry-*.json"))
    if not paths: raise RuntimeError("No compiled-cabin geometry exports found")
    rows = [validate(path) for path in paths]
    report = {"status": "PASS" if len(rows) == 3 and all(row["status"] == "PASS" for row in rows) else "INCONCLUSIVE", "vehicles": rows}
    (args.folder / "clearance.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if args.update_manifests:
        if report["status"] != "PASS": raise RuntimeError("Refusing to certify an inconclusive geometry set")
        root = Path(__file__).resolve().parents[1]
        profile_hash = hashlib.sha256((root / "assets/config/cockpit-profiles-v279.json").read_bytes()).hexdigest()
        for row in rows:
            target = root / "content/ultra" / ("cockpit279-" + row["vehicle"] + ".json")
            metadata = json.loads(target.read_text(encoding="utf-8-sig"))
            metadata.update(clearance_status="PASS", certified_clearance_lower_bound_m=row["certified_clearance_lower_bound_m"], clearance_method=row["method"], clearance_geometry_sha256=row["geometry_sha256"], cockpit_profile_sha256=profile_hash)
            target.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    sys.exit(0 if report["status"] == "PASS" else 1)
