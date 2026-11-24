# Analysis notes

Supporting detail for the [main README](../README.md). Nothing here changes the headline results; it holds the statistical checks that would slow down a first read. The tests below were run outside SQL Server.

## Missing income by country

Missing income is uneven by country: Australia 13 of 160 customers (8.1%), Germany 4 of 120, USA 2 of 109, all others under 1%.

- Australia against all other countries (13/160 vs 11/2,080): Fisher's exact p ≈ 1e-9.
- A permutation test that allows for picking the highest country out of all with 100+ customers: p < 0.001.

So the missingness is **not random across countries**. The test shows the pattern, not its cause, which is why income is flagged and not imputed with one overall value.

## Recency distribution

Recency is spread evenly from 0 to 99 days: about 210 to 230 customers in every 10-day band, and a Kolmogorov-Smirnov test against a uniform distribution gives p = 0.22. It is unrelated to spend (r = 0.02) or purchase count (r = 0.00). Real purchase data rarely behaves like that, so the field may be capped or partly synthetic.

It still carries signal for the final campaign (r = -0.20; 26.4% acceptance at 24 days or less vs 7.0% at 75 days or more), so the R score is not noise. Findings describe this dataset and may not transfer to a live customer base.
