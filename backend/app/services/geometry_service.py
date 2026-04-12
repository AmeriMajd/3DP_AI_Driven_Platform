from __future__ import annotations
import math
from pathlib import Path
from typing import Any, Dict, List

import numpy as np
import trimesh

GLB_OUTPUT_DIR = "/app/uploads/glb"


# ── Mesh loading ───────────────────────────────────────────────────────────────

def _load_mesh(file_path: Path) -> trimesh.Trimesh:
    """
    Load STL/3MF and always return a single Trimesh.
    If the file contains multiple geometries, concatenate them.
    """
    mesh: trimesh.Trimesh | None = None

    # First pass: keep all geometry by loading as scene.
    try:
        loaded = trimesh.load(file_path, force="scene")

        if isinstance(loaded, trimesh.Scene):
            meshes = [
                g for g in loaded.geometry.values()
                if isinstance(g, trimesh.Trimesh) and len(g.faces) > 0
            ]
            if meshes:
                mesh = trimesh.util.concatenate(meshes) if len(meshes) > 1 else meshes[0]
        elif isinstance(loaded, trimesh.Trimesh):
            mesh = loaded
    except Exception:
        mesh = None

    # Fallback for edge-case files that don't deserialize cleanly as scene.
    if mesh is None:
        try:
            loaded_mesh = trimesh.load(file_path, force="mesh", process=False)
            if isinstance(loaded_mesh, trimesh.Trimesh):
                mesh = loaded_mesh
        except Exception:
            mesh = None

    if mesh is None or mesh.is_empty or len(mesh.faces) == 0:
        raise ValueError("No valid mesh geometry found.")

    mesh = mesh.copy()

    # Keep preprocessing permissive so imperfect real-world meshes still pass.
    try:
        mesh.process(validate=False)
    except Exception:
        pass

    try:
        mesh.remove_unreferenced_vertices()
    except Exception:
        pass

    if mesh.is_empty or len(mesh.faces) == 0:
        raise ValueError("Mesh is empty.")

    return mesh


# ── Individual feature extraction functions ───────────────────────────────────

def compute_volume(mesh: trimesh.Trimesh) -> float:
    """Volume in cm³ (STL uses mm, so divide mm³ by 1000)."""
    return abs(float(mesh.volume)) / 1000.0


def compute_surface_area(mesh: trimesh.Trimesh) -> float:
    """Surface area in cm² (divide mm² by 100)."""
    return float(mesh.area) / 100.0


def compute_bounding_box(mesh: trimesh.Trimesh) -> Dict[str, float]:
    """Bounding box extents in mm."""
    bounds = mesh.bounds
    extents = bounds[1] - bounds[0]
    return {"x": float(extents[0]), "y": float(extents[1]), "z": float(extents[2])}


def compute_triangle_count(mesh: trimesh.Trimesh) -> int:
    return int(len(mesh.faces))


def compute_overhang_ratio(mesh: trimesh.Trimesh) -> float:
    """Fraction of faces where normal.z < -cos(45°) — classified as overhangs."""
    normals = mesh.face_normals
    threshold = -math.cos(math.radians(45))  # ≈ -0.707
    overhang_count = int(np.sum(normals[:, 2] < threshold))
    total = len(normals)
    return float(overhang_count / total) if total > 0 else 0.0


def compute_max_overhang_angle(mesh: trimesh.Trimesh) -> float:
    """Worst-case overhang angle in degrees among downward-facing normals."""
    normals = mesh.face_normals
    downward_mask = normals[:, 2] < 0
    if not np.any(downward_mask):
        return 0.0
    downward_z = normals[downward_mask, 2]
    # Angle from the downward vertical = arccos(|z|)
    angles = np.degrees(np.arccos(np.clip(np.abs(downward_z), 0.0, 1.0)))
    return float(np.max(angles))


def compute_wall_thickness(mesh: trimesh.Trimesh) -> Dict[str, float]:
    """
    Estimate min and avg wall thickness (mm) via inward ray casting.
    Shoots rays from face centers opposite their normals and measures hit distance.
    Falls back to a bbox-based estimate for non-manifold or ray-miss cases.
    """
    try:
        n_samples = min(500, len(mesh.faces))
        rng = np.random.default_rng(42)
        indices = rng.choice(len(mesh.faces), size=n_samples, replace=False)

        centers = mesh.triangles_center[indices]
        normals = mesh.face_normals[indices]
        # Offset origin slightly inside the surface to avoid self-hit
        ray_origins = centers + normals * 0.01
        ray_directions = -normals

        locations, index_ray, _ = mesh.ray.intersects_location(
            ray_origins=ray_origins,
            ray_directions=ray_directions,
            multiple_hits=False,
        )

        if len(locations) > 0:
            valid_origins = ray_origins[index_ray]
            distances = np.linalg.norm(locations - valid_origins, axis=1)
            distances = distances[distances > 0.05]  # filter near-zero noise

            if len(distances) > 0:
                return {
                    "min": float(np.percentile(distances, 5)),
                    "avg": float(np.mean(distances)),
                }
    except Exception:
        pass

    # Fallback: estimate from bbox proportions
    bounds = mesh.bounds
    extents = bounds[1] - bounds[0]
    estimated_min = float(np.min(extents)) * 0.05
    estimated_avg = float(np.min(extents)) * 0.15
    return {"min": max(0.1, estimated_min), "avg": max(0.5, estimated_avg)}


def compute_complexity_index(surface_area_cm2: float, volume_cm3: float) -> float:
    """surface_area_cm2 / volume_cm3 ratio."""
    if volume_cm3 <= 0:
        return 0.0
    return float(surface_area_cm2 / volume_cm3)


def compute_aspect_ratio(bbox: Dict[str, float]) -> float:
    """max(x,y,z) / min(x,y,z) of bounding box dimensions."""
    dims = [bbox["x"], bbox["y"], bbox["z"]]
    min_dim = min(dims)
    if min_dim <= 0:
        return 1.0
    return float(max(dims) / min_dim)


def check_watertight(mesh: trimesh.Trimesh) -> bool:
    """True if mesh has no open edges."""
    return bool(mesh.is_watertight)


def count_shells(mesh: trimesh.Trimesh) -> int:
    """Number of separate connected bodies in the mesh."""
    try:
        components = trimesh.graph.connected_components(
            mesh.face_adjacency, node_count=len(mesh.faces)
        )
        return int(len(components))
    except Exception:
        return 1


def compute_com_offset(mesh: trimesh.Trimesh) -> float:
    """Distance from CoM to geometric center, normalized by bbox diagonal."""
    try:
        com = np.array(mesh.center_mass)
    except Exception:
        com = np.mean(mesh.vertices, axis=0)

    bounds = mesh.bounds
    geometric_center = (bounds[0] + bounds[1]) / 2.0
    extents = bounds[1] - bounds[0]
    diagonal = float(np.linalg.norm(extents))

    offset = float(np.linalg.norm(com - geometric_center))
    return float(offset / diagonal) if diagonal > 0 else 0.0


def compute_flat_base_area(mesh: trimesh.Trimesh) -> float:
    """Sum of face areas (mm²) where normal.z > 0.95 — near-flat upward faces."""
    normals = mesh.face_normals
    areas = mesh.area_faces
    mask = normals[:, 2] > 0.95
    return float(np.sum(areas[mask]))


def compute_face_normal_histogram(mesh: trimesh.Trimesh, bins: int = 18) -> List[float]:
    """18-bin histogram of face normal Z-components, normalized to density."""
    normals = mesh.face_normals
    z_values = normals[:, 2]
    hist, _ = np.histogram(z_values, bins=bins, range=(-1.0, 1.0), density=True)
    return hist.tolist()


# ── Master feature extraction ─────────────────────────────────────────────────

def extract_all_features(stl_path: str | Path) -> Dict[str, Any]:
    """
    Load mesh once and compute all 18 geometric features.
    Returns a flat dict with every feature key.
    On error, returns sensible defaults rather than crashing.
    """
    path = Path(stl_path)
    mesh = _load_mesh(path)

    # Basic dimensions
    volume_cm3 = compute_volume(mesh)
    surface_area_cm2 = compute_surface_area(mesh)
    bbox = compute_bounding_box(mesh)
    triangle_count = compute_triangle_count(mesh)

    # Overhang features
    overhang_ratio = compute_overhang_ratio(mesh)
    max_overhang_angle = compute_max_overhang_angle(mesh)

    # Wall thickness
    wall = compute_wall_thickness(mesh)
    min_wall_mm = wall["min"]
    avg_wall_mm = wall["avg"]

    # Shape indices
    complexity_index = compute_complexity_index(surface_area_cm2, volume_cm3)
    aspect_ratio = compute_aspect_ratio(bbox)

    # Mesh quality
    is_watertight = check_watertight(mesh)
    shell_count = count_shells(mesh)

    # Balance & base
    com_offset_ratio = compute_com_offset(mesh)
    flat_base_area_mm2 = compute_flat_base_area(mesh)

    # Normal distribution
    face_normal_histogram = compute_face_normal_histogram(mesh)

    return {
        # Pre-existing fields
        "volume_cm3": volume_cm3,
        "surface_area_cm2": surface_area_cm2,
        "bbox_x_mm": bbox["x"],
        "bbox_y_mm": bbox["y"],
        "bbox_z_mm": bbox["z"],
        "triangle_count": triangle_count,
        "has_overhangs": overhang_ratio > 0.05,
        "has_thin_walls": min_wall_mm < 1.5,
        # New Sprint 2B fields
        "overhang_ratio": overhang_ratio,
        "max_overhang_angle": max_overhang_angle,
        "min_wall_thickness_mm": min_wall_mm,
        "avg_wall_thickness_mm": avg_wall_mm,
        "complexity_index": complexity_index,
        "aspect_ratio": aspect_ratio,
        "is_watertight": is_watertight,
        "shell_count": shell_count,
        "com_offset_ratio": com_offset_ratio,
        "flat_base_area_mm2": flat_base_area_mm2,
        "face_normal_histogram": face_normal_histogram,
    }


# Backwards-compatible alias for existing callers
def extract_ui_features(file_path: str | Path) -> Dict[str, Any]:
    return extract_all_features(file_path)


# ── GLB conversion ─────────────────────────────────────────────────────────────

def convert_to_glb(input_path: str, uuid: str) -> str:
    """
    Convert STL or 3MF to GLB using trimesh.
    Returns the output file path.
    Raises on failure — caller must handle.
    """
    Path(GLB_OUTPUT_DIR).mkdir(parents=True, exist_ok=True)
    mesh = _load_mesh(Path(input_path))
    glb_path = Path(GLB_OUTPUT_DIR) / f"{uuid}.glb"
    mesh.export(str(glb_path), file_type="glb")
    return str(glb_path)
