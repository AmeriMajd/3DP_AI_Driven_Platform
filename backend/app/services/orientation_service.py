"""
Orientation Optimizer — Sprint 2B
Deterministic algorithm (no ML). Samples 162 candidate orientations using the
Fibonacci lattice, scores each one, and returns the top 3.
"""
from __future__ import annotations
import math
from typing import Any, Dict, List

import numpy as np
import trimesh
from scipy.spatial.transform import Rotation


def generate_candidates(n: int = 162) -> np.ndarray:
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
    face_verts_z = rotated_vertices[faces, 2]          # (F, 3)
    centroid_z = face_verts_z.mean(axis=1)              # (F,)

    overhang_centroid_z = centroid_z[overhang_mask]
    overhang_areas = areas[overhang_mask]
    overhang_nz = np.abs(rotated_normals[overhang_mask, 2])

    # Project face area onto XY plane, multiply by height above plate
    projected = overhang_areas * overhang_nz
    heights = np.maximum(overhang_centroid_z - z_min, 0.0)
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


def angle_between(v1: np.ndarray, v2: np.ndarray) -> float:
    """Return the angle in degrees between two unit vectors."""
    dot = float(np.clip(np.dot(v1, v2), -1.0, 1.0))
    return math.degrees(math.acos(abs(dot)))


def score_orientation(
    overhang_area: float,
    base_area: float,
    print_height: float,
    support_vol: float,
    contact_area: float,
    com_offset_ratio: float,
    total_area: float,
    model_volume_cm3: float,
    max_diagonal: float,
    budget_priority: str = "quality",
    surface_finish: str = "standard",
    priority_face_bonus: float = 0.0,
) -> float:
    """
    Improved scoring with support volume normalisation, CoM stability, and
    an optional priority-face bonus.

      score = w_o*(1 - overhang/total)
            + w_b*(base/total)
            + w_h*(1 - height/diagonal)
            + w_s*(1 / (1 + support_norm*0.8))
            + w_st*(1 - min(com_offset*5, 1))
            + 0.08*priority_face_bonus
    """
    if total_area <= 0 or model_volume_cm3 <= 0:
        return 0.0

    overhang_term  = 1.0 - (overhang_area / total_area)
    base_term      = base_area / total_area
    height_term    = 1.0 - (print_height / max_diagonal) if max_diagonal > 0 else 0.0

    support_norm   = support_vol / (model_volume_cm3 * 1000)
    support_term   = 1.0 / (1.0 + support_norm * 0.8)

    stability_term = 1.0 - min(com_offset_ratio * 5.0, 1.0)

    contact_term = min(contact_area / 8000.0, 1.0)   # normalize, cap at ~5000 mm² good OR # normalize around 8000 mm² as "excellent"

    # Adjust weights slightly (total still ~1.0)
    w_o, w_b, w_h, w_s, w_st = 0.30, 0.30, 0.15, 0.18, 0.05   # base up from 0.25

    if budget_priority == "speed":
        w_h, w_s = 0.25, 0.10
    if surface_finish == "fine":
        w_o, w_s = 0.45, 0.10

    score = (
        w_o  * overhang_term
        + w_b  * base_term
        + w_h  * height_term
        + w_s  * support_term
        + w_st * stability_term
        + 0.15 * contact_term
        + 0.08 * priority_face_bonus
    )

    return float(np.clip(score, 0.0, 1.0))


def find_best_orientations(
    mesh: trimesh.Trimesh,
    priority_face: str = "none",
    priority_face_normal: "np.ndarray | None" = None,
    budget_priority: str = "quality",
    surface_finish: str = "standard",
    n_candidates: int = 200,
    min_diversity_angle: float = 15.0,
) -> List[Dict[str, Any]]:
    """
    Sample n_candidates orientations on a Fibonacci sphere, score each one
    with the improved scoring formula, apply diversity filtering so the
    returned top-3 orientations differ by at least min_diversity_angle degrees,
    and return the top 3.

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

    # CoM offset ratio — how far the centre of mass is from the bounding-box
    # centre, normalised by the diagonal (fallback: 0.05 if not on mesh object)
    com_offset_ratio = float(getattr(mesh, "com_offset_ratio", 0.05))

    # Baseline overhang (original orientation) for reduction % calculation
    baseline_overhang = compute_overhang_area(normals, areas)

    candidates = generate_candidates(n_candidates)
    scored: List[Dict[str, Any]] = []

    for candidate in candidates:
        R               = _rotation_matrix_to_align_z(candidate)
        rotated_normals = rotate_normals(normals, R)
        rotated_verts   = (R @ vertices.T).T

        overhang    = compute_overhang_area(rotated_normals, areas)
        base        = compute_base_area(rotated_normals, areas)
        height      = float(rotated_verts[:, 2].max() - rotated_verts[:, 2].min())
        support_vol = compute_support_volume(faces, rotated_verts, rotated_normals, areas)
        contact     = compute_contact_area(rotated_normals, areas)

        # Priority-face bonus: reward orientations where the candidate direction
        # is close to the requested face normal (cos similarity → [0, 1])
        if priority_face_normal is not None:
            pf_norm = priority_face_normal / (np.linalg.norm(priority_face_normal) + 1e-12)
            priority_face_bonus = float(np.clip(np.dot(candidate, pf_norm), 0.0, 1.0))
        else:
            priority_face_bonus = 0.0

        score = score_orientation(
            overhang_area      = overhang,
            base_area          = base,
            print_height       = height,
            support_vol        = support_vol,
            contact_area       = contact,
            com_offset_ratio   = com_offset_ratio,
            total_area         = total_area,
            model_volume_cm3   = model_volume_cm3,
            max_diagonal       = max_diagonal,
            budget_priority    = budget_priority,
            surface_finish     = surface_finish,
            priority_face_bonus= priority_face_bonus,
        )

        if baseline_overhang > 0:
            reduction_pct = round(
                (baseline_overhang - overhang) / baseline_overhang * 100.0, 1
            )
        else:
            reduction_pct = 0.0

        rot   = Rotation.from_matrix(R)
        euler = rot.as_euler("xyz", degrees=True)

        scored.append({
            "score":                score,
            "_candidate":           candidate,          # unit vector, used for diversity check
            "rx_deg":               round(float(euler[0]), 2),
            "ry_deg":               round(float(euler[1]), 2),
            "rz_deg":               round(float(euler[2]), 2),
            "overhang_reduction_pct": reduction_pct,
            "print_height_mm":      round(height, 2),
            "support_volume_mm3":   round(support_vol, 2),
            "contact_area_mm2":     round(contact, 2),
            "build_height_mm":      round(height, 2),
        })

    # ── Sort by score descending ──────────────────────────────────────────────
    scored.sort(key=lambda x: x["score"], reverse=True)

    # ── Diversity filtering: greedily pick up to 3 orientations that are at
    #    least min_diversity_angle degrees apart from each other ──────────────
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

    # Fallback: if diversity filtering left fewer than 3 results (very
    # symmetric mesh), fill up with the next best un-selected candidates.
    if len(selected) < 3:
        chosen_indices = {id(s) for s in selected}
        for item in scored:
            if id(item) not in chosen_indices:
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
