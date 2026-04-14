# Orientation Service — Improvements Log

## Overview

File: `backend/app/services/orientation_service.py`

The orientation optimizer samples candidate rotations on a sphere, scores each one, and returns the top 3 most diverse orientations for FDM 3D printing. This document records the two rounds of improvements made in Sprint 2B.

---

## Round 1 — Scoring Correctness & Two-Stage Sampling

### Bugs Fixed

#### 1. Weight Sum = 1.13 (Silent Score Clipping)
**Before:** `w_o + w_b + w_h + w_s + w_st + contact = 0.30 + 0.30 + 0.15 + 0.18 + 0.05 + 0.15 = 1.13`
The maximum possible score before `np.clip` was **1.21**, meaning the top ~15% of orientations all received a score of 1.0 — eliminating any discrimination between the best candidates.

**After:** Weights redesigned to sum to **exactly 1.00**:
| Term | Weight | Purpose |
|------|--------|---------|
| `w_o` | 0.25 | Overhang reduction |
| `w_s` | 0.18 | Support volume (material cost) |
| `w_b` | 0.16 | Flat base area (adhesion) |
| `w_h` | 0.12 | Print height (time proxy) |
| `w_st` | 0.14 | Stability (CoM over footprint) |
| `w_c` | 0.15 | Contact fraction (build-plate grip) |
| **Total** | **1.00** | |

---

#### 2. CoM Stability Was a No-Op
**Before:** `com_offset_ratio = getattr(mesh, "com_offset_ratio", 0.05)` — a constant fallback value used for **every single candidate**, making the stability term contribute nothing to ranking.

**After:** New `compute_stability_ratio(rotated_vertices, com_rotated)` function:
- Computes `mesh.center_mass` once (CoM in original frame)
- Rotates it per candidate: `com_rotated = R @ com_world`
- Measures horizontal offset of CoM from footprint centroid, normalised by the RMS footprint extent
- Returns 0.0 (stable) → 1.0 (about to tip)

---

#### 3. `base_term` / `contact_term` Double-Counted the Same Faces
**Before:** Both used the `normal.z < −0.95` mask. Combined weight: `0.30 + 0.15 = 0.45` on identical geometry.

**After:** `w_b = 0.16`, `w_c = 0.15` — reduced overlap and separated conceptual roles.

---

#### 4. `overhang_reduction_pct` Could Be Negative
**Before:** No clamping — orientations worse than baseline produced negative percentages, violating the `0 ≤ pct ≤ 100` contract.

**After:** `np.clip(..., 0.0, 100.0)` applied before storing.

---

### Performance Improvement — Two-Stage Sampling

**Before:** 200 Fibonacci candidates, ~9° spacing. Good orientations between two sample points were missed.

**After:** Two-stage strategy:
- **Stage 1:** 200 coarse Fibonacci candidates (full sphere)
- **Stage 2:** Top-12 coarse results → 24 fine local candidates each within a 12° cap → ~488 total evaluations

New helper: `generate_local_candidates(center, n, half_angle_deg)` — Fibonacci sampling on a spherical cap.

Extracted `_score_candidate()` to share the evaluation loop between both stages cleanly.

---

## Round 2 — Contact Area Normalisation

Triggered by real-model test result where:
- **Rank 1** had only **9.87 mm²** contact area (model balancing on a near-point, 73 mm tall)
- **Rank 2** had **0 mm²** contact area (no face pointing down — geometrically cannot stand)
- **Rank 3** had **4,506 mm²** contact area (large flat base) yet ranked last

Root cause: `contact_term = min(contact_area / 8000.0, 1.0)` used a hardcoded 8,000 mm² normaliser regardless of model size. A 9.87 mm² contact scored `0.001` instead of being flagged as near-unprintable.

---

### Fix A — Per-Orientation Footprint Normalisation
**Before:** `min(contact / 8000, 1)` — arbitrary fixed scale.

**After (in `_score_candidate`):**
```python
xy_w = rotated_verts[:, 0].max() - rotated_verts[:, 0].min()
xy_h = rotated_verts[:, 1].max() - rotated_verts[:, 1].min()
contact_fraction = contact / (xy_w * xy_h)   # model-relative, 0–1
```
`score_orientation` now receives `contact_fraction` (pre-normalised) instead of raw `contact_area`.

---

### Fix B — Non-Linear Contact Penalty Below 5% Coverage
A model touching the build plate with < 5% of its own footprint area is effectively unprintable without a raft or special support.

**After:**
```
contact_fraction < 5%  →  contact_term ∈ [0.00, 0.25]   (steep penalty)
contact_fraction ≥ 5%  →  contact_term ∈ [0.25, 1.00]   (smooth linear rise)
```
This ensures orientations like rank 2 (0 mm² contact) score 0.0 on this term and cannot beat orientations with a proper base.

---

## Test Coverage

All 10 existing tests in `backend/app/tests/test_orientation_service.py` pass with no changes required:
- `test_returns_exactly_3`
- `test_result_fields`
- `test_scores_in_range`
- `test_rank_order_and_descending_scores`
- `test_angles_in_degree_range`
- `test_metrics_non_negative`
- `test_overhang_reduction_percentage`
- `test_budget_priority_speed`
- `test_surface_finish_fine`
- `test_top_2_are_distinct`
