"""
Orientation Optimizer — Sprint 2B (improved)

Deterministic algorithm (no ML). Samples candidate orientations using a
two-stage Fibonacci strategy:
  Stage 1 – 200 coarse Fibonacci candidates covering the full sphere.
  Stage 2 – 24 fine local candidates around each of the top-12 coarse
             results (≈ 488 total), converging on the actual optimum.

Scoring improvements over the previous version:
  • Weights now sum to exactly 1.0 (no silent clipping).
  • Stability is computed per-orientation (CoM horizontal offset from
    footprint centroid) instead of being a constant mesh property.
  • base_term / contact_term overlap resolved: contact weight reduced.
  • overhang_reduction_pct clamped to [0, 100].
"""
from __future__ import annotations
import math
from typing import Any, Dict, List

import numpy as np
import trimesh
from scipy.spatial.transform import Rotation


# ── Candidate generation ──────────────────────────────────────────────────────

def generate_candidates(n: int = 200) -> np.ndarray:
    """
    Generate n unit vectors uniformly distributed on a sphere
    using the Fibonacci lattice method.
    Returns array of shape (n, 3).
    """
    golden_ratio = (1.0 + math.sqrt(5.0)) / 2.0
    indices = np.arange(n)
    theta = np.arccos(1.0 - 2.0 * (indices + 0.5) / n)
    phi = 2.0 * math.pi * indices / golden_ratio

    x = np.sin(theta) * np.cos(phi)
    y = np.sin(theta) * np.sin(phi)
    z = np.cos(theta)
    return np.column_stack([x, y, z])


def generate_local_candidates(
    center: np.ndarray,
    n: int = 24,
    half_angle_deg: float = 12.0,
) -> np.ndarray:
    """
    Generate n unit vectors uniformly distributed within a spherical cap of
    half_angle_deg around `center`, using the Fibonacci lattice on the cap.
    Returns array of shape (n, 3).
    """
    center = center / (np.linalg.norm(center) + 1e-12)
    half_angle = math.radians(half_angle_deg)
    cos_min = math.cos(half_angle)

    golden_ratio = (1.0 + math.sqrt(5.0)) / 2.0
    indices = np.arange(n)

    # Uniform sampling of cos(theta) in [cos_min, 1]
    cos_theta = cos_min + (1.0 - cos_min) * (indices + 0.5) / n
    theta = np.arccos(np.clip(cos_theta, -1.0, 1.0))
    phi = 2.0 * math.pi * indices / golden_ratio

    x_local = np.sin(theta) * np.cos(phi)
    y_local = np.sin(theta) * np.sin(phi)
    z_local = np.cos(theta)
    local_vecs = np.column_stack([x_local, y_local, z_local])

    # Rotate local frame so local +Z aligns with `center`
    R = _rotation_matrix_to_align_z(center)
    global_vecs = (R @ local_vecs.T).T

    norms = np.linalg.norm(global_vecs, axis=1, keepdims=True)
    return global_vecs / (norms + 1e-12)


# ── Geometry helpers ──────────────────────────────────────────────────────────

def _rotation_matrix_to_align_z(target: np.ndarray) -> np.ndarray:
    """
    Build a 3×3 rotation matrix R such that R maps +Z → target.
    Uses Rodrigues' rotation formula.
    """
    z = np.array([0.0, 0.0, 1.0])
    target = target / np.linalg.norm(target)

    axis = np.cross(z, target)
    axis_norm = np.linalg.norm(axis)

    if axis_norm < 1e-8:
        # Vectors are (anti-)parallel
        return np.eye(3) if np.dot(z, target) > 0 else np.diag([1.0, -1.0, -1.0])

    axis = axis / axis_norm
    angle = math.acos(float(np.clip(np.dot(z, target), -1.0, 1.0)))

    K = np.array([
        [0.0,     -axis[2],  axis[1]],
        [axis[2],  0.0,     -axis[0]],
        [-axis[1], axis[0],  0.0],
    ])
    R = np.eye(3) + math.sin(angle) * K + (1.0 - math.cos(angle)) * (K @ K)
    return R


def rotate_normals(normals: np.ndarray, R: np.ndarray) -> np.ndarray:
    """Apply rotation matrix R to all face normals. Returns array of same shape."""
    return (R @ normals.T).T


# ── Per-orientation metrics ───────────────────────────────────────────────────

def compute_overhang_area(rotated_normals: np.ndarray, areas: np.ndarray) -> float:
    """Sum areas of faces where rotated normal.z < -0.707 (cos 45°)."""
    mask = rotated_normals[:, 2] < -0.707
    return float(np.sum(areas[mask]))


def compute_base_area(rotated_normals: np.ndarray, areas: np.ndarray) -> float:
    """Sum areas of faces where rotated normal.z < -0.95 (nearly flat-down)."""
    mask = rotated_normals[:, 2] < -0.95
    return float(np.sum(areas[mask]))


def compute_print_height(vertices: np.ndarray, R: np.ndarray) -> float:
    """Max z minus min z of all rotated vertices."""
    rotated = (R @ vertices.T).T
    return float(rotated[:, 2].max() - rotated[:, 2].min())


def compute_support_volume(
    faces: np.ndarray,
    rotated_vertices: np.ndarray,
    rotated_normals: np.ndarray,
    areas: np.ndarray,
) -> float:
    """
    Estimate support material volume (mm³) for a given orientation.
    For each overhang face (normal.z < -0.707), support volume ≈
    projected_area × height_of_centroid_above_build_plate.
    """
    overhang_mask = rotated_normals[:, 2] < -0.707
    if not np.any(overhang_mask):
        return 0.0

    z_min = float(rotated_vertices[:, 2].min())

    # Face centroid Z = mean Z of the 3 constituent vertices
    face_verts_z = rotated_vertices[faces, 2]      # (F, 3)
    centroid_z   = face_verts_z.mean(axis=1)        # (F,)

    overhang_centroid_z = centroid_z[overhang_mask]
    overhang_areas      = areas[overhang_mask]
    overhang_nz         = np.abs(rotated_normals[overhang_mask, 2])

    projected = overhang_areas * overhang_nz
    heights   = np.maximum(overhang_centroid_z - z_min, 0.0)
    return float(np.sum(projected * heights))


def compute_contact_area(rotated_normals: np.ndarray, areas: np.ndarray) -> float:
    """
    Estimate build-plate contact area (mm²).
    Sums the XY-projected area of faces that are nearly flat-down (normal.z < -0.95).
    """
    mask = rotated_normals[:, 2] < -0.95
    if not np.any(mask):
        return 0.0
    return float(np.sum(areas[mask] * np.abs(rotated_normals[mask, 2])))


def compute_stability_ratio(
    rotated_vertices: np.ndarray,
    com_rotated: np.ndarray,
) -> float:
    """
    Per-orientation stability: horizontal distance of the centre of mass
    from the footprint centroid, normalised by the RMS footprint extent.

    Returns a ratio in [0, 1]:
      0.0 = CoM directly over footprint centre (maximally stable)
      1.0 = CoM at the edge of the footprint (about to tip)

    The footprint is defined as vertices within the bottom 3 % of model
    height (or 1 mm, whichever is larger).
    """
    z_min   = float(rotated_vertices[:, 2].min())
    z_range = float(rotated_vertices[:, 2].max()) - z_min
    z_thresh = z_min + max(z_range * 0.03, 1.0)

    mask = rotated_vertices[:, 2] <= z_thresh
    footprint_pts = rotated_vertices[mask, :2]

    if len(footprint_pts) < 3:
        # Degenerate footprint — treat as slightly off-centre
        return 0.3

    centroid_xy = footprint_pts.mean(axis=0)

    # RMS extent gives a size-representative radius of the footprint
    rms_extent = float(
        np.sqrt(np.mean(np.sum((footprint_pts - centroid_xy) ** 2, axis=1)) + 1e-6)
    )

    com_xy_offset = float(np.linalg.norm(com_rotated[:2] - centroid_xy))
    return float(np.clip(com_xy_offset / (rms_extent + 1e-6), 0.0, 1.0))


# ── Scoring ───────────────────────────────────────────────────────────────────

def angle_between(v1: np.ndarray, v2: np.ndarray) -> float:
    """Return the angle in degrees between two unit vectors."""
    dot = float(np.clip(np.dot(v1, v2), -1.0, 1.0))
    return math.degrees(math.acos(abs(dot)))


def score_orientation(
    overhang_area: float,
    base_area: float,
    print_height: float,
    support_vol: float,
    contact_fraction: float,
    stability_ratio: float,
    total_area: float,
    model_volume_cm3: float,
    max_diagonal: float,
    budget_priority: str = "quality",
    surface_finish: str = "standard",
    priority_face_bonus: float = 0.0,
) -> float:
    """
    Score an orientation in [0, 1].  Weights sum to exactly 1.0 so that
    the formula spans the full range without silent clipping distortion.

    `contact_fraction` is the build-plate contact area divided by the
    model's XY footprint area for that orientation (0–1).  This makes
    the contact term scale-independent and properly penalises orientations
    where the model barely touches the build plate.

      Base weights (quality / standard):
        w_o  = 0.25  overhang reduction   (key FDM metric)
        w_s  = 0.18  support volume       (material cost)
        w_b  = 0.16  flat base area       (adhesion & first layer)
        w_h  = 0.12  print height         (build time proxy)
        w_st = 0.14  stability            (CoM over footprint, per orientation)
        w_c  = 0.15  contact fraction     (build-plate grip, model-relative)
                                    sum = 1.00

      priority_face_bonus (0–0.08) is additive; clipped overall to 1.0.

    Mode overrides redistribute weights while keeping the total at 1.0.
    """
    if total_area <= 0 or model_volume_cm3 <= 0:
        return 0.0

    overhang_term  = 1.0 - (overhang_area / total_area)
    base_term      = base_area / total_area
    height_term    = 1.0 - (print_height / max_diagonal) if max_diagonal > 0 else 0.0

    support_norm   = support_vol / (model_volume_cm3 * 1000.0)
    support_term   = 1.0 / (1.0 + support_norm * 0.8)

    stability_term = 1.0 - stability_ratio   # high stability_ratio = bad

    # Non-linear contact term: hard penalty below 5 % footprint coverage.
    # Orientations that barely touch the plate (< 5 %) score at most 0.25
    # on this term, preventing them from ranking above well-grounded ones.
    cf = float(np.clip(contact_fraction, 0.0, 1.0))
    if cf < 0.05:
        contact_term = (cf / 0.05) * 0.25          # 0.00 → 0.25 for 0 → 5 %
    else:
        contact_term = 0.25 + (cf - 0.05) / 0.95 * 0.75   # 0.25 → 1.00 for 5 → 100 %

    # Default balanced weights — sum = 1.00
    w_o, w_s, w_b, w_h, w_st, w_c = 0.25, 0.18, 0.16, 0.12, 0.14, 0.15

    if budget_priority == "speed":
        # Prioritise shorter print: boost height & support weight
        w_o, w_s, w_b, w_h, w_st, w_c = 0.22, 0.16, 0.12, 0.25, 0.13, 0.12

    if surface_finish == "fine":
        # Prioritise overhang reduction for surface quality
        w_o, w_s, w_b, w_h, w_st, w_c = 0.38, 0.18, 0.14, 0.10, 0.12, 0.08

    score = (
        w_o  * overhang_term
        + w_s  * support_term
        + w_b  * base_term
        + w_h  * height_term
        + w_st * stability_term
        + w_c  * contact_term
        + 0.08 * priority_face_bonus
    )

    return float(np.clip(score, 0.0, 1.0))


# ── Main entry point ──────────────────────────────────────────────────────────

def _score_candidate(
    candidate: np.ndarray,
    normals: np.ndarray,
    areas: np.ndarray,
    vertices: np.ndarray,
    faces: np.ndarray,
    com_world: np.ndarray,
    total_area: float,
    model_volume_cm3: float,
    max_diagonal: float,
    baseline_overhang: float,
    budget_priority: str,
    surface_finish: str,
    priority_face_normal: "np.ndarray | None",
) -> Dict[str, Any]:
    """Compute all metrics and score for a single candidate direction."""
    R               = _rotation_matrix_to_align_z(candidate)
    rotated_normals = rotate_normals(normals, R)
    rotated_verts   = (R @ vertices.T).T
    com_rotated     = R @ com_world

    overhang    = compute_overhang_area(rotated_normals, areas)
    base        = compute_base_area(rotated_normals, areas)
    height      = float(rotated_verts[:, 2].max() - rotated_verts[:, 2].min())
    support_vol = compute_support_volume(faces, rotated_verts, rotated_normals, areas)
    contact     = compute_contact_area(rotated_normals, areas)
    stability   = compute_stability_ratio(rotated_verts, com_rotated)

    # Normalise contact by the XY bounding-box footprint area of *this*
    # orientation so the term is model-size-independent.
    xy_w = float(rotated_verts[:, 0].max() - rotated_verts[:, 0].min())
    xy_h = float(rotated_verts[:, 1].max() - rotated_verts[:, 1].min())
    footprint_area = max(xy_w * xy_h, 1e-6)
    contact_fraction = float(np.clip(contact / footprint_area, 0.0, 1.0))

    if priority_face_normal is not None:
        pf_norm = priority_face_normal / (np.linalg.norm(priority_face_normal) + 1e-12)
        pf_bonus = float(np.clip(np.dot(candidate, pf_norm), 0.0, 1.0))
    else:
        pf_bonus = 0.0

    score = score_orientation(
        overhang_area      = overhang,
        base_area          = base,
        print_height       = height,
        support_vol        = support_vol,
        contact_fraction   = contact_fraction,
        stability_ratio    = stability,
        total_area         = total_area,
        model_volume_cm3   = model_volume_cm3,
        max_diagonal       = max_diagonal,
        budget_priority    = budget_priority,
        surface_finish     = surface_finish,
        priority_face_bonus= pf_bonus,
    )

    if baseline_overhang > 0:
        reduction_pct = float(
            np.clip((baseline_overhang - overhang) / baseline_overhang * 100.0, 0.0, 100.0)
        )
    else:
        reduction_pct = 0.0

    rot   = Rotation.from_matrix(R)
    euler = rot.as_euler("xyz", degrees=True)

    return {
        "score":                    score,
        "_candidate":               candidate,
        "rx_deg":                   round(float(euler[0]), 2),
        "ry_deg":                   round(float(euler[1]), 2),
        "rz_deg":                   round(float(euler[2]), 2),
        "overhang_reduction_pct":   reduction_pct,
        "print_height_mm":          round(height, 2),
        "support_volume_mm3":       round(support_vol, 2),
        "contact_area_mm2":         round(contact, 2),
        "build_height_mm":          round(height, 2),
    }


def find_best_orientations(
    mesh: trimesh.Trimesh,
    priority_face: str = "none",
    priority_face_normal: "np.ndarray | None" = None,
    budget_priority: str = "quality",
    surface_finish: str = "standard",
    n_candidates: int = 200,
    min_diversity_angle: float = 15.0,
    n_refine_top: int = 12,
    n_local: int = 24,
    local_half_angle: float = 12.0,
) -> List[Dict[str, Any]]:
    """
    Two-stage orientation search:

    Stage 1 — score `n_candidates` Fibonacci lattice orientations.
    Stage 2 — take the top `n_refine_top` coarse results and generate
               `n_local` fine local candidates (within `local_half_angle`°)
               around each; score those too.

    All coarse + fine candidates are merged, sorted, then diversity-filtered
    so the returned top-3 differ by at least `min_diversity_angle` degrees.

    Each result dict contains:
      { rank, rx_deg, ry_deg, rz_deg, score,
        overhang_reduction_pct, print_height_mm,
        support_volume_mm3, contact_area_mm2, build_height_mm }
    """
    normals  = mesh.face_normals.copy()
    areas    = mesh.area_faces.copy()
    vertices = mesh.vertices.copy()
    faces    = mesh.faces.copy()

    total_area       = float(np.sum(areas))
    model_volume_cm3 = float(mesh.volume / 1000.0)

    bounds       = mesh.bounds
    extents      = bounds[1] - bounds[0]
    max_diagonal = float(np.linalg.norm(extents))

    # Centre of mass in original (unrotated) mesh frame — constant, rotated per candidate
    com_world = np.asarray(mesh.center_mass, dtype=float)

    # Baseline overhang for reduction % (original orientation)
    baseline_overhang = compute_overhang_area(normals, areas)

    # ── Shared kwargs ─────────────────────────────────────────────────────────
    kwargs = dict(
        normals              = normals,
        areas                = areas,
        vertices             = vertices,
        faces                = faces,
        com_world            = com_world,
        total_area           = total_area,
        model_volume_cm3     = model_volume_cm3,
        max_diagonal         = max_diagonal,
        baseline_overhang    = baseline_overhang,
        budget_priority      = budget_priority,
        surface_finish       = surface_finish,
        priority_face_normal = priority_face_normal,
    )

    # ── Stage 1: coarse Fibonacci sampling ───────────────────────────────────
    coarse_candidates = generate_candidates(n_candidates)
    scored: List[Dict[str, Any]] = [
        _score_candidate(c, **kwargs) for c in coarse_candidates
    ]

    # ── Stage 2: fine local sampling around top-K coarse results ─────────────
    coarse_sorted = sorted(scored, key=lambda x: x["score"], reverse=True)
    top_k = [item["_candidate"] for item in coarse_sorted[:n_refine_top]]

    seen: set = set()
    for tc in top_k:
        for lc in generate_local_candidates(tc, n=n_local, half_angle_deg=local_half_angle):
            key = tuple(np.round(lc, 3))
            if key not in seen:
                seen.add(key)
                scored.append(_score_candidate(lc, **kwargs))

    # ── Sort all candidates by score descending ───────────────────────────────
    scored.sort(key=lambda x: x["score"], reverse=True)

    # ── Diversity filtering: greedily select up to 3 orientations that are
    #    at least min_diversity_angle degrees apart from each other ────────────
    selected: List[Dict[str, Any]] = []
    for item in scored:
        candidate = item["_candidate"]
        if all(
            angle_between(candidate, s["_candidate"]) >= min_diversity_angle
            for s in selected
        ):
            selected.append(item)
        if len(selected) == 3:
            break

    # Fallback: if diversity filtering produced fewer than 3 (very symmetric
    # mesh), fill up with the next best un-selected candidates.
    if len(selected) < 3:
        chosen_ids = {id(s) for s in selected}
        for item in scored:
            if id(item) not in chosen_ids:
                selected.append(item)
            if len(selected) == 3:
                break

    # ── Build final output (strip internal _candidate key) ───────────────────
    top3 = []
    for rank, item in enumerate(selected, start=1):
        top3.append({
            "rank":                   rank,
            "rx_deg":                 item["rx_deg"],
            "ry_deg":                 item["ry_deg"],
            "rz_deg":                 item["rz_deg"],
            "score":                  round(item["score"], 4),
            "overhang_reduction_pct": item["overhang_reduction_pct"],
            "print_height_mm":        item["print_height_mm"],
            "support_volume_mm3":     item["support_volume_mm3"],
            "contact_area_mm2":       item["contact_area_mm2"],
            "build_height_mm":        item["build_height_mm"],
        })

    return top3
