"""Step 1: aggregate the daily fact table into monthly commodity/district tables.

Reads  data/*.csv
Writes build/*.pkl (consumed by 03_build_workbook.py)
The logic lives in monthly_aggregation.py so the Jupyter notebook can reuse it.
"""
from pathlib import Path
from monthly_aggregation import aggregate, save
ROOT = Path(__file__).resolve().parents[1]
res = aggregate(ROOT / 'data')
save(res, ROOT / 'build')
print('monthly rows:', len(res['m']), '| district-item-month rows:', len(res['dpm']))
