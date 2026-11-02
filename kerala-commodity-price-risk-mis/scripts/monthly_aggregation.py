"""Daily -> monthly aggregation used by the pipeline and the notebook.

aggregate(data_dir) returns a dict of DataFrames:
  m    commodity x month: state average, districts reporting, district dispersion (CV), breadth of rise
  dpm  district x commodity x month: district mean, state mean, premium vs state, eligibility
  md   month table: days reported, last date reported
  sea  seasonal index (as supplied)
  di   commodity dimension with display label, months with data, districts reporting
  dd   district dimension
"""
from pathlib import Path
import pandas as pd, numpy as np

MIN_OBS = 5          # daily observations needed for a district-month to count
BREADTH_PCT = 0.10   # a district is "up" if its month mean is >10% above its own prior-12M average


def aggregate(data_dir, min_obs=MIN_OBS):
    U = str(Path(data_dir)) + '/'
    f = pd.read_csv(U + 'fact_daily_prices_clean.csv')
    di = pd.read_csv(U + 'dim_item.csv'); dd = pd.read_csv(U + 'dim_district.csv')
    dt = pd.read_csv(U + 'dim_date.csv', parse_dates=['full_date'])
    f = f.merge(dt[['date_id', 'full_date']], on='date_id')
    f['month'] = f.full_date.values.astype('datetime64[M]')

    # district-item-month means (district-month needs >= min_obs daily observations)
    g = f.groupby(['item_id', 'district_id', 'month']).price.agg(['mean', 'size']).reset_index()
    g = g[g['size'] >= min_obs].rename(columns={'mean': 'd_avg', 'size': 'n_obs'})

    # state average = equal-weight mean of district monthly means; dispersion = CV across districts
    s = g.groupby(['item_id', 'month']).d_avg.agg(state_avg='mean', n_districts='size', sd='std').reset_index()
    s['disp_cv'] = np.where(s.n_districts >= 3, s.sd / s.state_avg, np.nan)

    # breadth: share of districts > +10% above their own trailing-12M average (prior 12 months, >= 6 obs)
    months = pd.date_range(f.month.min(), f.month.max(), freq='MS')
    full = pd.MultiIndex.from_product([di.item_id.unique(), dd.district_id, months],
                                      names=['item_id', 'district_id', 'month'])
    gp = g.set_index(['item_id', 'district_id', 'month']).d_avg.reindex(full).reset_index()
    gp = gp.sort_values(['item_id', 'district_id', 'month'])
    gp['own12'] = gp.groupby(['item_id', 'district_id']).d_avg.transform(
        lambda x: x.shift(1).rolling(12, min_periods=6).mean())
    gp['has'] = gp.d_avg.notna() & gp.own12.notna()
    gp['up10'] = (gp.d_avg > (1 + BREADTH_PCT) * gp.own12) & gp.has
    b = gp.groupby(['item_id', 'month']).agg(n_hist=('has', 'sum'), n_up=('up10', 'sum')).reset_index()
    b['breadth'] = np.where(b.n_hist >= 3, b.n_up / b.n_hist.replace(0, np.nan), np.nan)

    # commodity x month grid (every commodity has every month, blank where no data)
    grid = pd.MultiIndex.from_product([sorted(di.item_id.unique()), months], names=['item_id', 'month']).to_frame(index=False)
    m = (grid.merge(s[['item_id', 'month', 'state_avg', 'n_districts', 'disp_cv']], on=['item_id', 'month'], how='left')
             .merge(b[['item_id', 'month', 'breadth']], on=['item_id', 'month'], how='left'))

    # district premium vs state average
    dpm = g.merge(s[['item_id', 'month', 'state_avg', 'n_districts']], on=['item_id', 'month'])
    dpm['premium'] = dpm.d_avg / dpm.state_avg - 1
    dpm['eligible'] = (dpm.n_districts >= 5).astype(int)
    dpm = dpm.merge(di[['item_id', 'item_group']], on='item_id').merge(dd, on='district_id')

    # month table
    md = f.groupby('month').agg(days=('full_date', 'nunique'), last=('full_date', 'max')).reset_index()
    md['month_end'] = md.month + pd.offsets.MonthEnd(0)
    md['partial'] = ((md.month_end - md['last']).dt.days > 3).astype(int)

    sea = pd.read_csv(U + 'seasonal_index.csv')

    di['label'] = di.item_name_clean.str.strip() + ' [' + di.unit + ']'
    assert di.label.is_unique, 'display labels must be unique'
    cnt = g.groupby('item_id').agg(months_with_data=('month', 'nunique'), districts=('district_id', 'nunique')).reset_index()
    di = di.merge(cnt, on='item_id', how='left')
    return dict(m=m, dpm=dpm, md=md, sea=sea, di=di, dd=dd)


def save(res, build_dir):
    build_dir = Path(build_dir); build_dir.mkdir(exist_ok=True)
    for k, v in res.items():
        v.to_pickle(build_dir / f'{k}.pkl')
