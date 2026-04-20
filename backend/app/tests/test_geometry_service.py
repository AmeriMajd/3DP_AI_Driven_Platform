"""
Integration tests for geometry extraction.
Validates that extract_features_from_mesh returns correct values
for a known unit-cube mesh (1 mm × 1 mm × 1 mm, 12 triangles).
"""
import pytest
import numpy as np
import trimesh
from app.services.geometry_service import extract_features_from_mesh


@pytest.fixture
def cube_mesh():
    vertices = np.array([
        [0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0],
        [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1],
    ], dtype=np.float32)
    faces = np.array([
        [0, 1, 2], [0, 2, 3],
        [4, 6, 5], [4, 7, 6],
        [0, 4, 5], [0, 5, 1],
        [2, 6, 7], [2, 7, 3],
        [0, 3, 7], [0, 7, 4],
        [1, 5, 6], [1, 6, 2],
    ])
    return trimesh.Trimesh(vertices=vertices, faces=faces, process=False)


def test_basic_fields_present(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    expected = {
        "volume_cm3", "surface_area_cm2", "bbox_x_mm", "bbox_y_mm", "bbox_z_mm",
        "triangle_count", "has_overhangs", "has_thin_walls", "overhang_ratio",
        "max_overhang_angle", "min_wall_thickness_mm", "avg_wall_thickness_mm",
        "complexity_index", "aspect_ratio", "is_watertight", "shell_count",
        "com_offset_ratio", "flat_base_area_mm2", "face_normal_histogram",
    }
    assert expected.issubset(set(result.keys()))


def test_volume_and_surface_area(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    # 1 mm³ = 0.001 cm³ ; 6 mm² = 0.06 cm²
    assert 0.0 < result["volume_cm3"] < 0.01
    assert 0.05 < result["surface_area_cm2"] < 0.07


def test_bounding_box(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    assert result["bbox_x_mm"] == pytest.approx(1.0, rel=0.01)
    assert result["bbox_y_mm"] == pytest.approx(1.0, rel=0.01)
    assert result["bbox_z_mm"] == pytest.approx(1.0, rel=0.01)


def test_triangle_count(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    assert result["triangle_count"] == 12


def test_watertight(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    assert result["is_watertight"] is True


def test_shell_count(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    assert result["shell_count"] == 1


def test_aspect_ratio_cube(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    assert 0.9 < result["aspect_ratio"] < 1.1


def test_complexity_index_positive(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    assert result["complexity_index"] > 0.0


def test_com_offset_in_range(cube_mesh):
    result = extract_features_from_mesh(cube_mesh)
    assert 0.0 <= result["com_offset_ratio"] <= 1.0
