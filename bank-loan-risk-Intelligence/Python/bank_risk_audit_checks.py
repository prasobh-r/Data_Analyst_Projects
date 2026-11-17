"""
Bank Risk Intelligence: audit checks.

Reproduces, from the CSVs already in the repo, the numbers behind each audit finding,
so every claim can be verified instead of trusted.

Run from the repo root:   python bank_risk_audit_checks.py
Needs: pandas, numpy, scikit-learn
Reads: Dataset/loans_model_ready.csv, Dataset/loans_scored.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score, roc_curve

DATA = Path("Dataset")
df = pd.read_csv(DATA / "loans_model_ready.csv")
scored = pd.read_csv(DATA / "loans_scored.csv")

# Same time split as notebook 04: first 70% of vintage months = train
vintages = sorted(df.vintage_month.unique())
train_vintages = set(vintages[: int(len(vintages) * 0.7)])
is_train = df.vintage_month.isin(train_vintages)
train, test = df[is_train], df[~is_train]

CONT = ["loan_amnt", "monthly_income", "dti", "bureau_score", "revol_util", "inq_last_6mths"]
CAT = ["purpose", "home_ownership"]


def woe_from_counts(g):
    g = g.copy()
    g.columns = ["n", "bad"]
    g["good"] = g.n - g.bad
    dist_good = (g.good + 0.5) / (g.good.sum() + 0.5 * len(g))
    dist_bad = (g.bad + 0.5) / (g.bad.sum() + 0.5 * len(g))
    woe = np.log(dist_good / dist_bad)
    iv = float(((dist_good - dist_bad) * woe).sum())
    return woe, iv


def fit_woe(fit_df, cont, cat):
    spec = {}
    for f in cont:
        d = fit_df[[f, "defaulted"]].dropna().copy()
        d["bin"], edges = pd.qcut(d[f], q=10, duplicates="drop", retbins=True)
        woe, _ = woe_from_counts(d.groupby("bin", observed=True).defaulted.agg(["count", "sum"]))
        spec[f] = ("c", edges, woe)
    for f in cat:
        d = fit_df[[f, "defaulted"]].fillna("Unknown")
        woe, _ = woe_from_counts(d.groupby(f).defaulted.agg(["count", "sum"]))
        spec[f] = ("k", None, woe)
    return spec


def apply_woe(d, spec):
    out = pd.DataFrame(index=d.index)
    for f, (kind, edges, woe) in spec.items():
        if kind == "c":
            binned = pd.cut(d[f], bins=edges, include_lowest=True).astype(str)
            out[f] = binned.map(dict(zip(woe.index.astype(str), woe.values)))
        else:
            out[f] = d[f].fillna("Unknown").map(woe.to_dict())
        out[f] = out[f].fillna(out[f].mean())
    return out


def evaluate(fit_df, cont, cat, label):
    spec = fit_woe(fit_df, cont, cat)
    model = LogisticRegression(max_iter=1000).fit(apply_woe(train, spec), train.defaulted)
    p = model.predict_proba(apply_woe(test, spec))[:, 1]
    auc = roc_auc_score(test.defaulted, p)
    fpr, tpr, _ = roc_curve(test.defaulted, p)
    print(f"  {label:62s} AUC {auc:.4f}  KS {100 * np.max(tpr - fpr):.2f}")


print("=" * 78)
print("CHECK 1: term_months (36 vs 60 months) was dropped with IV = 0")
print("=" * 78)
t = df.groupby("term_months").defaulted.agg(["count", "mean"])
print(t.round(4).to_string())
n_bins = pd.qcut(df.term_months, q=10, duplicates="drop").nunique()
_, iv_term = woe_from_counts(df.groupby("term_months").defaulted.agg(["count", "sum"]))
print(f"  Bins produced by the notebook's pd.qcut(q=10, duplicates='drop'): {n_bins}  -> IV 0.000")
print(f"  IV when term is treated as a 2-category feature: {iv_term:.4f}  (bureau_score is 0.1325)")

print()
print("=" * 78)
print("CHECK 2: effect of fitting WOE on all data vs training data only (test AUC / KS)")
print("=" * 78)
evaluate(df, CONT, CAT, "A. as in the notebook: WOE fitted on ALL 150,000 loans")
evaluate(train, CONT, CAT, "B. WOE fitted on TRAIN only, same 8 features")
evaluate(train, CONT, CAT + ["term_months"], "C. WOE fitted on TRAIN only, 8 features + term")

print()
print("=" * 78)
print("CHECK 3: does the model add anything beyond LendingClub's own grade? (out-of-time)")
print("=" * 78)
d = df.merge(scored, on="id")
d["grade_rank"] = d.grade.map({g: i for i, g in enumerate("ABCDEFG")})
d["sub_rank"] = d.sub_grade.map({s: i for i, s in enumerate(sorted(d.sub_grade.unique()))})
tr, te = d[d.vintage_month.isin(train_vintages)], d[~d.vintage_month.isin(train_vintages)]
print(f"  Test set: {len(te):,} loans, vintages {te.vintage_month.min()} to {te.vintage_month.max()}")
print(f"  LC grade alone          AUC {roc_auc_score(te.defaulted, te.grade_rank):.4f}")
print(f"  LC sub_grade alone      AUC {roc_auc_score(te.defaulted, te.sub_rank):.4f}")
print(f"  Model score alone       AUC {roc_auc_score(te.defaulted, -te.model_score):.4f}")
for col, label in [("grade_rank", "LC grade"), ("sub_rank", "LC sub_grade")]:
    base = LogisticRegression(max_iter=1000).fit(tr[[col]], tr.defaulted)
    both = LogisticRegression(max_iter=1000).fit(tr[[col, "model_score"]], tr.defaulted)
    a0 = roc_auc_score(te.defaulted, base.predict_proba(te[[col]])[:, 1])
    a1 = roc_auc_score(te.defaulted, both.predict_proba(te[[col, "model_score"]])[:, 1])
    print(f"  {label} + model score     AUC {a1:.4f}  (gain over {label} alone: {a1 - a0:+.4f})")

print()
print("=" * 78)
print("CHECK 4: the 'model grade within every LendingClub grade' claim")
print("=" * 78)
order = list("ABCDEFG")
for name, sub in [("ALL 150,000 loans (about 90% were used to train the model)", d),
                  ("OUT-OF-TIME TEST ONLY", te)]:
    print(f"\n  {name}")
    for g, x in sub.groupby("grade"):
        r = x.groupby("model_risk_grade").defaulted.mean().reindex(order)
        n = x.groupby("model_risk_grade").defaulted.size().reindex(order)
        mono = bool(r.dropna().is_monotonic_increasing)
        print(f"    LC grade {g}: monotonic A->G = {str(mono):5s} | smallest cell n = {int(n.min())}")
    b = sub[sub.grade == "B"].groupby("model_risk_grade").defaulted.agg(["count", "mean"]).reindex(order)
    print(f"    Grade B default by model grade: "
          + ", ".join(f"{k} {v * 100:.1f}%" for k, v in b["mean"].items()))
    print(f"    Grade B spread: {b['mean'].min() * 100:.1f}% to {b['mean'].max() * 100:.1f}% "
          f"= {b['mean'].max() / b['mean'].min():.2f}x")

print()
print("=" * 78)
print("CHECK 5: the 'revol_util sign flip is multicollinearity with dti and loan_amnt' claim")
print("=" * 78)
woe = pd.read_csv(DATA / "loans_woe_transformed.csv").drop(columns=["id", "defaulted"])
corr = woe.corr()
print(f"  corr(revol_util, bureau_score) = {corr.loc['revol_util_woe', 'bureau_score_woe']:.2f}")
print(f"  corr(revol_util, dti)          = {corr.loc['revol_util_woe', 'dti_woe']:.2f}")
print(f"  corr(revol_util, loan_amnt)    = {corr.loc['revol_util_woe', 'loan_amnt_woe']:.2f}")
vif = np.diag(np.linalg.inv(np.corrcoef(woe.values.T)))
print("  VIF: " + ", ".join(f"{c.replace('_woe', '')} {v:.2f}" for c, v in zip(woe.columns, vif)))
print("  (VIF above about 5 is the usual warning level)")

print()
print("=" * 78)
print("CHECK 6: README numbers that DO hold")
print("=" * 78)
exp = d.groupby("addr_state").loan_amnt.sum()
print(f"  CA+TX+NY+FL share of exposure: {100 * exp[['CA', 'TX', 'NY', 'FL']].sum() / exp.sum():.1f}%")
sb = d[d.purpose == "small_business"]
print(f"  small_business: n={len(sb):,}, default {sb.defaulted.mean() * 100:.1f}%")
dec = pd.qcut(d.dti, 10, labels=False, duplicates="drop")
r = d.groupby(dec).defaulted.mean() * 100
print(f"  DTI decile default: {r.iloc[0]:.1f}% (lowest) to {r.iloc[-1]:.1f}% (highest)")
v = d.groupby("vintage_month").defaulted.mean() * 100
print(f"  vintage peak: {v.idxmax()} at {v.max():.2f}%; first month {v.iloc[0]:.2f}%")
print(f"  overall default rate: {d.defaulted.mean() * 100:.2f}%")
