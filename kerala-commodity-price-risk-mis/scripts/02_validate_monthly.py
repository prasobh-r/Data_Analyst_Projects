"""Optional: cross-check recomputed monthly state averages against archive/monthly_price_changes.csv."""
import pandas as pd
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"data"
BUILD=ROOT/"build"; BUILD.mkdir(exist_ok=True)
m=pd.read_pickle(BUILD/'m.pkl')
mp=pd.read_csv(ROOT/'archive'/'monthly_price_changes.csv'); mp['month']=pd.to_datetime(mp.year_month+'-01')
c=mp.merge(m,on=['item_id','month']); c['diff']=(c.avg_price/c.state_avg-1).abs()
print('state_avg vs monthly_price_changes: median %.4f | p95 %.4f | max %.3f'%(c['diff'].median(),c['diff'].quantile(.95),c['diff'].max()))
