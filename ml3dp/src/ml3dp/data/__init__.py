"""ml3dp.data — schema, rules, and synthetic data generator."""

from . import rules, schema
from .generator import GeneratorConfig, generate_dataset

__all__ = ["rules", "schema", "GeneratorConfig", "generate_dataset"]
