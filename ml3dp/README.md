# 3D Printing Recommendation — ML Module

Three-stage cascade (Tech → Material → Parameters) for recommending
3D printing settings from a part's geometry plus user intent.

This repo holds the **ML pipeline only** — it produces trained models that
the FastAPI backend (sibling repo) loads via `joblib`.

## Project layout

```
ml3dp/
├── docs/crisp-dm/        Phase docs (chapter raw material)
├── src/ml3dp/            Python package
│   ├── data/             Schema, rules, synthetic generator
│   ├── features/         Encoders + scalers
│   ├── models/           Per-stage training scripts
│   ├── benchmark/        Cross-family benchmark
│   ├── diagnostic/       Per-stage failure analysis
│   └── evaluation/       Metric definitions
├── scripts/              CLI entry points (numbered)
├── data/                 Datasets (gitignored)
├── reports/              Auto-generated CSVs + figures
├── models_ml/            Final .joblib artifacts (gitignored)
└── tests/                Verification tests
```

## Quickstart

```bash
# 1. Install
pip install -r requirements.txt

# 2. Generate the synthetic dataset (Session 1)
python scripts/01_generate_dataset.py

# 3. Run verification tests
python tests/test_session1.py
```

## Methodology

CRISP-DM with the CRISP-ML(Q) quality-assurance extension. Each phase has
a markdown doc under `docs/crisp-dm/`; those docs become the corresponding
sections of the thesis chapter.

Lock dataset config:
--noise 0.15 --param-noise 0.10 --feature-noise 0.05 --tech-noise 0.08
