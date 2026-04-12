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

# Default scoring weights
_W1_DEFAULT = 0.40  # minimize overhangs
_W2_DEFAULT = 0.30  # maximize flat base for bed adhesion
_W3_DEFAULT = 0.20  # minimize print height (speed)
_W4_DEFAULT = 0.10  # priority face bonus


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


def score_orientation(
    overhang_area: float,
    base_area: float,
    print_height: float,
    total_area: float,
    max_diagonal: float,
    budget_priority: str = "quality",
    surface_finish: str = "standard",
) -> float:
    """
    Weighted scoring formula:
      score = w1*(1 - overhang/total) + w2*(base/total)
            + w3*(1 - height/diagonal) + w4*priority_face_score
    """
    w1, w2, w3, w4 = _W1_DEFAULT, _W2_DEFAULT, _W3_DEFAULT, _W4_DEFAULT

    if budget_priority == "speed":
        w3, w2 = 0.35, 0.15
    if surface_finish == "fine":
        w4, w3 = 0.25, 0.05

    if total_area <= 0:
        return 0.0

    overhang_term = 1.0 - (overhang_area / total_area)
    base_term = base_area / total_area
    height_term = (1.0 - print_height / max_diagonal) if max_diagonal > 0 else 0.0
    priority_face_score = 0.5  # neutral when no specific face is requested

    return float(
        w1 * overhang_term
        + w2 * base_term
        + w3 * height_term
        + w4 * priority_face_score
    )


def find_best_orientations(
    mesh: trimesh.Trimesh,
    priority_face: str = "none",
    budget_priority: str = "quality",
    surface_finish: str = "standard",
    n_candidates: int = 162,
) -> List[Dict[str, Any]]:
    """
    Sample n_candidates orientations, score each one, return the top 3.
    Each result dict:
      { rank, rx_deg, ry_deg, rz_deg, score,
        overhang_reduction_pct, print_height_mm }
    """
    normals = mesh.face_normals.copy()
    areas = mesh.area_faces.copy()
    vertices = mesh.vertices.copy()
    total_area = float(np.sum(areas))

    bounds = mesh.bounds
    extents = bounds[1] - bounds[0]
    max_diagonal = float(np.linalg.norm(extents))

    # Baseline overhang (no rotation) for reduction % calculation
    baseline_overhang = compute_overhang_area(normals, areas)

    candidates = generate_candidates(n_candidates)
    scored: List[Dict[str, Any]] = []

    for candidate in candidates:
        R = _rotation_matrix_to_align_z(candidate)
        rotated_normals = rotate_normals(normals, R)

        overhang = compute_overhang_area(rotated_normals, areas)
        base = compute_base_area(rotated_normals, areas)
        height = compute_print_height(vertices, R)

        score = score_orientation(
            overhang_area=overhang,
            base_area=base,
            print_height=height,
            total_area=total_area,
            max_diagonal=max_diagonal,
            budget_priority=budget_priority,
            surface_finish=surface_finish,
        )

        # Overhang reduction vs. baseline orientation
        if baseline_overhang > 0:
            reduction_pct = round(
                (baseline_overhang - overhang) / baseline_overhang * 100.0, 1
            )
        else:
            reduction_pct = 0.0

        # Convert rotation matrix → Euler angles XYZ (degrees)
        rot = Rotation.from_matrix(R)
        euler = rot.as_euler("xyz", degrees=True)

        scored.append({
            "score": score,
            "rx_deg": round(float(euler[0]), 2),
            "ry_deg": round(float(euler[1]), 2),
            "rz_deg": round(float(euler[2]), 2),
            "overhang_reduction_pct": reduction_pct,
            "print_height_mm": round(height, 2),
        })

    # Sort by score descending and return top 3
    scored.sort(key=lambda x: x["score"], reverse=True)

    top3 = []
    for rank, item in enumerate(scored[:3], start=1):
        top3.append({
            "rank": rank,
            "rx_deg": item["rx_deg"],
            "ry_deg": item["ry_deg"],
            "rz_deg": item["rz_deg"],
            "score": round(item["score"], 4),
            "overhang_reduction_pct": item["overhang_reduction_pct"],
            "print_height_mm": item["print_height_mm"],
        })

    return top3
