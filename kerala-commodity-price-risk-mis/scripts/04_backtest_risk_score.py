"""Step 4: backtest of the risk score (does a high score precede a price rise?).

Reads  data/*.csv (re-runs the monthly aggregation and the scoring, so step 01 is not required)
Writes backtest/*.csv and docs/screenshots/backtest.png

Design
  Unit      : one scored commodity-month (Jan 2024 to Jan 2026 have a next month; Feb 2026 has no future)
  Signal    : risk score and class (Red >= 65, Amber >= 40, Green) as published in the workbook
  Outcomes  : price change from month t to month t+1 (primary, one month ahead, non-overlapping)
              and from t to t+3 (secondary, windows overlap, so read it as a description, not a test)
  Event     : price rises 5% or more next month (3% and 10% shown as a sensitivity check)
  Baselines : (a) base rate, (b) the volatility component alone, (c) the commodity's own past frequency
              of 5% monthly rises (12 prior months), (d) last month's price change
  Uncertainty: 95% intervals from a bootstrap that resamples whole commodities (months of one commodity
              are not independent), seed fixed.

Important limits (also written in docs/BACKTEST.md)
  * The weights, caps and thresholds were calibrated on this same period, so this is an in-sample check,
    not a true out-of-sample test.
  * The seasonal index uses all three years (look-ahead); a run with the seasonal weight set to 0 is included.
  * Only 25 monthly cross-sections; Red has 82 usable observations from a few commodities.
"""
from pathlib import Path
import numpy as np, pandas as pd
from scipy import stats
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from monthly_aggregation import aggregate
from risk_score import score, W

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'backtest'; OUT.mkdir(exist_ok=True)
SEED, NBOOT = 20260218, 1000
EVENT = 0.05
rng = np.random.default_rng(SEED)

# ---------------------------------------------------------------- build the panel
res = aggregate(ROOT / 'data')
m, sea, di = res['m'], res['sea'], res['di']


def build_panel(weights=W):
    s = score(m, sea, W=weights).merge(di[['item_id', 'label', 'item_group']], on='item_id')
    s = s.sort_values(['item_id', 'month']).reset_index(drop=True)
    g = s.groupby('item_id')
    s['f1'] = g.state_avg.shift(-1) / s.state_avg - 1          # next month
    s['f3'] = g.state_avg.shift(-3) / s.state_avg - 1          # three months ahead
    # baseline (c): share of the 12 prior months with a rise of EVENT or more (needs 6 months of history)
    up = (s.mom >= EVENT).astype(float).where(s.mom.notna())
    s['hist_rate'] = up.groupby(s.item_id).transform(lambda x: x.shift(1).rolling(12, min_periods=6).mean())
    s['prev_mom'] = s.mom
    return s


panel = build_panel()
use = panel[(panel.elig == 1) & panel.f1.notna()].copy()
use['event'] = (use.f1 >= EVENT).astype(int)
print(f'usable commodity-months: {len(use)} ({use.month.min():%b %Y} to {use.month.max():%b %Y}); '
      f'{use.item_id.nunique()} commodities; base rate of a >= {EVENT:.0%} rise next month: {use.event.mean():.1%}')

items = use.item_id.unique()


# ---------------------------------------------------------------- helpers
def auc(x, y):
    """Probability that a random event row has a higher score than a random non-event row (ties count half)."""
    x = np.asarray(x, float); y = np.asarray(y, int)
    ok = ~np.isnan(x); x, y = x[ok], y[ok]
    n1 = y.sum(); n0 = len(y) - n1
    if n1 == 0 or n0 == 0:
        return np.nan
    r = stats.rankdata(x)
    return (r[y == 1].sum() - n1 * (n1 + 1) / 2) / (n1 * n0)


def boot_items(func, df, nboot=NBOOT):
    """95% interval of func(df) when whole commodities are resampled."""
    groups = {k: v for k, v in df.groupby('item_id')}
    keys = np.array(list(groups))
    out = []
    for _ in range(nboot):
        pick = rng.choice(keys, size=len(keys), replace=True)
        try:
            out.append(func(pd.concat([groups[k] for k in pick])))
        except Exception:
            pass
    out = np.array(out, float)
    return np.nanpercentile(out, [2.5, 97.5])


# ---------------------------------------------------------------- 1. outcome by alert class
rows = []
base = use.event.mean()
for cls in ['Red', 'Amber', 'Green']:
    d = use[use.cls == cls]
    lo, hi = boot_items(lambda x: x.event.mean(), d)
    d3 = panel[(panel.elig == 1) & panel.f3.notna() & (panel.cls == cls)]
    rows.append(dict(
        alert_class=cls, n=len(d), commodities=d.item_id.nunique(),
        pct_rise_5pct_next_month=d.event.mean(), ci_low=lo, ci_high=hi,
        lift_vs_base=d.event.mean() / base,
        median_change_next_month=d.f1.median(),
        median_change_3m=d3.f3.median(), share_lower_after_3m=(d3.f3 < 0).mean(), n_3m=len(d3)))
by_class = pd.DataFrame(rows)
by_class.to_csv(OUT / 'backtest_by_class.csv', index=False)

# sensitivity to the event definition
sens = []
for thr in (0.03, 0.05, 0.10):
    e = (use.f1 >= thr)
    r = {'event_threshold': f'next-month rise >= {thr:.0%}', 'base_rate': e.mean()}
    for cls in ['Red', 'Amber', 'Green']:
        r[cls] = e[use.cls == cls].mean()
    r['AUC_risk'] = auc(use.risk, e.astype(int))
    sens.append(r)
pd.DataFrame(sens).to_csv(OUT / 'backtest_event_sensitivity.csv', index=False)

# ---------------------------------------------------------------- 2. discrimination vs baselines
cands = {
    'Composite risk score': 'risk',
    'Volatility component only': 's_vol',
    'Momentum component only': 's_mom',
    'Deviation vs 12M average only': 's_dev',
    'YoY component only': 's_yoy',
    'District dispersion only': 's_disp',
    'Breadth of rise only': 's_brd',
    'Seasonal component only': 's_sea',
    "Baseline: own past frequency of 5% rises": 'hist_rate',
    "Baseline: last month's price change": 'prev_mom',
}
rows = []
for name, col in cands.items():
    d = use[use.event.notna()]
    a = auc(d[col], d.event)
    lo, hi = boot_items(lambda x, c=col: auc(x[c], x.event), d, nboot=500)
    # within-commodity AUC: does the score time the rises of one commodity? (commodities with >=3 events and >=3 non-events)
    w = []
    for _, x in d.groupby('item_id'):
        if x.event.sum() >= 3 and (len(x) - x.event.sum()) >= 3 and x[col].nunique() > 1:
            w.append(auc(x[col], x.event))
    rows.append(dict(signal=name, auc_all=a, ci_low=lo, ci_high=hi,
                     within_commodity_auc=np.nanmean(w), commodities_tested=len(w),
                     share_commodities_above_0_5=np.mean(np.array(w) > .5)))
auc_tab = pd.DataFrame(rows)
auc_tab.to_csv(OUT / 'backtest_auc.csv', index=False)

# ---------------------------------------------------------------- 3. cross-sectional check each month
ic = use.groupby('month').apply(lambda d: stats.spearmanr(d.risk, d.f1)[0] if d.risk.nunique() > 3 else np.nan,
                                include_groups=False).dropna()
top5 = use.sort_values(['month', 'risk'], ascending=[True, False]).groupby('month').head(5)
cross = dict(months=int(ic.size), mean_rank_correlation=ic.mean(),
             t_stat=ic.mean() / ic.std(ddof=1) * np.sqrt(ic.size), months_positive=int((ic > 0).sum()),
             top5_hit_rate=top5.event.mean(), top5_n=len(top5), all_hit_rate=base,
             top5_hit_rate_by_past_frequency=use.sort_values(['month', 'hist_rate'], ascending=[True, False])
                                                 .groupby('month').head(5).event.mean())
pd.Series(cross).to_csv(OUT / 'backtest_monthly_cross_section.csv', header=['value'])

# ---------------------------------------------------------------- 4. stability and robustness
rob = []


def summarise(d, label):
    r = {'run': label, 'n': len(d), 'base_rate': d.event.mean(), 'AUC_risk': auc(d.risk, d.event)}
    for cls in ['Red', 'Amber', 'Green']:
        r[f'{cls}_rate'] = d.event[d.cls == cls].mean(); r[f'{cls}_n'] = int((d.cls == cls).sum())
    return r


rob.append(summarise(use, 'All months (headline)'))
rob.append(summarise(use[use.month < '2025-01-01'], '2024 only'))
rob.append(summarise(use[use.month >= '2025-01-01'], '2025 to Jan 2026'))
# seasonal weight 0 removes the look-ahead of the full-sample seasonal index
alt = build_panel({**W, 'sea': 0.0})
u2 = alt[(alt.elig == 1) & alt.f1.notna()].copy(); u2['event'] = (u2.f1 >= EVENT).astype(int)
rob.append(summarise(u2, 'Seasonal weight set to 0'))
# leave out the five most frequently Red commodities
top_red = use[use.cls == 'Red'].groupby('item_id').size().sort_values(ascending=False).head(5).index
rob.append(summarise(use[~use.item_id.isin(top_red)], 'Without the 5 most-often Red commodities'))
pd.DataFrame(rob).to_csv(OUT / 'backtest_robustness.csv', index=False)

# ---------------------------------------------------------------- 5. the panel itself, for audit
cols = ['label', 'item_group', 'month', 'state_avg', 'risk', 'cls', 'type', 'signal', 'mom', 'vol', 'dev', 'yoy',
        'f1', 'f3', 'event', 'hist_rate']
out = use[cols].copy(); out['month'] = out.month.dt.strftime('%Y-%m')
out.round(4).to_csv(OUT / 'backtest_panel.csv', index=False)

# ---------------------------------------------------------------- 6. chart
fig, ax = plt.subplots(1, 2, figsize=(11, 4.2))
cls_order = ['Green', 'Amber', 'Red']; colr = {'Green': '#2e8b57', 'Amber': '#e0a21f', 'Red': '#c0392b'}
bc = by_class.set_index('alert_class').loc[cls_order]
ax[0].bar(cls_order, bc.pct_rise_5pct_next_month * 100, color=[colr[c] for c in cls_order],
          yerr=[(bc.pct_rise_5pct_next_month - bc.ci_low) * 100, (bc.ci_high - bc.pct_rise_5pct_next_month) * 100],
          capsize=4)
ax[0].axhline(base * 100, ls='--', c='grey'); ax[0].text(-0.45, base * 100 + 1.2, f'all months {base:.1%}', ha='left', color='dimgrey')
for i, c in enumerate(cls_order):
    ax[0].text(i, 1, f'n={int(bc.n[c])}', ha='center', color='white', fontsize=9)
ax[0].set_ylabel('% of commodity-months'); ax[0].set_title('Price up 5%+ next month')
d3 = panel[(panel.elig == 1) & panel.f3.notna()]
data = [d3[d3.cls == c].f3.mul(100).values for c in cls_order]
bp = ax[1].boxplot(data, patch_artist=True, showfliers=False)
ax[1].set_xticks([1, 2, 3]); ax[1].set_xticklabels(cls_order)   # works on matplotlib 3.8 and later
for patch, c in zip(bp['boxes'], cls_order):
    patch.set_facecolor(colr[c]); patch.set_alpha(.7)
ax[1].axhline(0, c='k', lw=.8); ax[1].set_ylabel('% change in 3 months'); ax[1].set_title('Price change three months later')
fig.suptitle('Backtest of the risk score, Jan 2024 to Jan 2026 (in-sample, 60 commodities)', fontsize=11)
plt.tight_layout(); fig.savefig(ROOT / 'docs' / 'screenshots' / 'backtest.png', dpi=160); plt.close()

# ---------------------------------------------------------------- print a readable summary
pd.set_option('display.width', 220); pd.set_option('display.max_columns', 30)
print('\nBY CLASS'); print(by_class.round(3).to_string(index=False))
print('\nEVENT SENSITIVITY'); print(pd.DataFrame(sens).round(3).to_string(index=False))
print('\nAUC'); print(auc_tab.round(3).to_string(index=False))
print('\nCROSS-SECTION'); print(pd.Series(cross).round(3).to_string())
print('\nROBUSTNESS'); print(pd.DataFrame(rob).round(3).to_string(index=False))
