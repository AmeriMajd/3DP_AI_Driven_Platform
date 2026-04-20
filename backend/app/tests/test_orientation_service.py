"""
Integration tests for orientation optimization.
Validates that find_best_orientations returns 3 valid, ordered,
diverse orientations with correct field structure and value ranges.
"""
import pytest
import numpy as np
import trimesh
from app.services.orientation_service import find_best_orientations


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


def _orientations(mesh, **kwargs):
    return find_best_orientations(mesh, n_candidates=100, **kwargs)


def test_returns_exactly_3(cube_mesh):
    assert len(_orientations(cube_mesh)) == 3


def test_result_fields(cube_mesh):
    required = {
        "rank", "rx_deg", "ry_deg", "rz_deg", "score",
        "overhang_reduction_pct", "print_height_mm",
        "support_volume_mm3", "contact_area_mm2", "build_height_mm",
    }
    for o in _orientations(cube_mesh):
        assert required.issubset(set(o.keys()))


def test_scores_in_range(cube_mesh):
    for o in _orientations(cube_mesh):
        assert 0.0 <= o["score"] <= 1.0


def test_rank_order_and_descending_scores(cube_mesh):
    results = _orientations(cube_mesh)
    assert [o["rank"] for o in results] == [1, 2, 3]
    scores = [o["score"] for o in results]
    assert scores[0] >= scores[1] >= scores[2]


def test_angles_in_degree_range(cube_mesh):
    for o in _orientations(cube_mesh):
        for key in ("rx_deg", "ry_deg", "rz_deg"):
            assert -180 <= o[key] <= 180


def test_metrics_non_negative(cube_mesh):
    for o in _orientations(cube_mesh):
        assert o["print_height_mm"] > 0
        assert o["support_volume_mm3"] >= 0
        assert o["contact_area_mm2"] >= 0
        assert o["build_height_mm"] > 0


def test_overhang_reduction_percentage(cube_mesh):
    for o in _orientations(cube_mesh):
        assert 0.0 <= o["overhang_reduction_pct"] <= 100.0


def test_budget_priority_speed(cube_mesh):
    results = _orientations(cube_mesh, budget_priority="speed")
    assert len(results) == 3
    assert all(0.0 <= o["score"] <= 1.0 for o in results)


def test_surface_finish_fine(cube_mesh):
    results = _orientations(cube_mesh, surface_finish="fine")
    assert len(results) == 3
    assert all(0.0 <= o["score"] <= 1.0 for o in results)


def test_top_2_are_distinct(cube_mesh):
    results = _orientations(cube_mesh, min_diversity_angle=15.0)
    r1 = (results[0]["rx_deg"], results[0]["ry_deg"], results[0]["rz_deg"])
    r2 = (results[1]["rx_deg"], results[1]["ry_deg"], results[1]["rz_deg"])
    assert r1 != r2
