from __future__ import annotations
from pathlib import Path
from typing import Any, Dict, List
import numpy as np
import trimesh

GLB_OUTPUT_DIR = "/app/uploads/glb"


def _load_mesh(file_path: Path) -> trimesh.Trimesh:
    """
    Load STL/3MF and always return a single Trimesh.
    If the file contains multiple geometries, concatenate them.
    """
    loaded = trimesh.load(file_path, force="scene")

    if isinstance(loaded, trimesh.Scene):
        meshes = [
            g for g in loaded.geometry.values()
            if isinstance(g, trimesh.Trimesh) and len(g.faces) > 0
        ]
        if not meshes:
            raise ValueError("No valid mesh geometry found.")
        mesh = trimesh.util.concatenate(meshes)
    elif isinstance(loaded, trimesh.Trimesh):
        mesh = loaded
    else:
        raise ValueError("Unsupported mesh type.")

    if mesh.is_empty or len(mesh.faces) == 0:
        raise ValueError("Mesh is empty.")

    mesh = mesh.copy().process(validate=True)
    mesh.remove_unreferenced_vertices()

    return mesh


def _face_normal_histogram(mesh: trimesh.Trimesh, bins: int = 12) -> List[float]:
    """
    Histogram of face normal Z-components.
    Returns a small numeric signature useful for orientation analysis.
    """
    normals = mesh.face_normals
    z_values = normals[:, 2]
    hist, _ = np.histogram(z_values, bins=bins, range=(-1.0, 1.0), density=True)
    return hist.tolist()


def _orientation_candidates() -> Dict[str, Any]:
    """
    Temporary placeholder orientations.
    Replace later with your real optimal-orientation scoring logic.
    """
    return {
        "best_orientation_1": {"rx": 0, "ry": 0, "rz": 0, "label": "default"},
        "best_orientation_2": {"rx": 90, "ry": 0, "rz": 0, "label": "x_90"},
        "best_orientation_3": {"rx": 0, "ry": 90, "rz": 0, "label": "y_90"},
        "best_orientation_score": None,
    }


def extract_ui_features(file_path: str | Path) -> Dict[str, Any]:
    """
    Extract only the UI-visible features:
    - volume
    - surface area
    - bounding box
    - triangle count
    - face normal histogram
    - top-3 candidate orientations
    """
    path = Path(file_path)
    mesh = _load_mesh(path)

    bounds = mesh.bounds
    extents = bounds[1] - bounds[0]

    bbox_x_mm = float(extents[0])
    bbox_y_mm = float(extents[1])
    bbox_z_mm = float(extents[2])

    mesh_volume_mm3 = abs(float(mesh.volume))
    mesh_area_mm2 = float(mesh.area)

    volume_cm3 = mesh_volume_mm3 / 1000.0
    surface_area_cm2 = mesh_area_mm2 / 100.0

    features: Dict[str, Any] = {
        "volume_cm3": volume_cm3,
        "surface_area_cm2": surface_area_cm2,
        "bbox_x_mm": bbox_x_mm,
        "bbox_y_mm": bbox_y_mm,
        "bbox_z_mm": bbox_z_mm,
        "triangle_count": int(len(mesh.faces)),
        "face_normal_histogram": _face_normal_histogram(mesh),
    }

    features.update(_orientation_candidates())
    return features


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