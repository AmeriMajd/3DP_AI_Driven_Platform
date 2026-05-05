"""
Pricing & estimation constants. Single source of truth for cost/time math.
Bump PRICING_VERSION whenever any value below changes.
"""

PRICING_VERSION = "2026.05.01"
CURRENCY = "TND"

NOZZLE_WIDTH_MM = 0.4
SETUP_FEE_TND = 10.0
SLA_PER_LAYER_SECONDS = 8.0

MATERIAL_DENSITY_G_PER_CM3 = {
    "PLA": 1.24,
    "PETG": 1.27,
    "ABS": 1.04,
    "TPU": 1.21,
    "Resin-Standard": 1.10,
    "Resin-Engineering": 1.15,
}
DEFAULT_DENSITY = 1.24  # PLA-equivalent

MATERIAL_PRICE_TND_PER_KG = {
    "PLA": 90,
    "PETG": 110,
    "ABS": 100,
    "TPU": 160,
    "Resin-Standard": 220,
    "Resin-Engineering": 320,
}
DEFAULT_PRICE_PER_KG = 90  # PLA-equivalent

MACHINE_RATE_TND_PER_HOUR = {"FDM": 8, "SLA": 14}
DEFAULT_MACHINE_RATE = 8  # FDM-equivalent

# Sanity bounds — outputs exceeding these are treated as garbage.
MAX_EFFECTIVE_VOLUME_CM3 = 10000          # 10 L
MAX_TIME_MINUTES = 7 * 24 * 60            # 7 days

# Edge-overcounting correction for raw shell volume (concave edges/corners
# get double-counted by surface_area * thickness).
SHELL_EDGE_CORRECTION = 0.85
