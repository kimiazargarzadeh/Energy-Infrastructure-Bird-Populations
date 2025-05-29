# Replication of Katovich (2023): Energy Infrastructure & Bird Populations

This repository contains code and replication materials for a Difference-in-Differences (DiD) analysis estimating the impact of shale oil/gas and wind infrastructure on U.S. bird populations (2000–2020). The study replicates the empirical strategy of Katovich (2023) using large-scale panel data from the Audubon Christmas Bird Count (CBC).

## Overview

- **Method**: Two-way fixed effects DiD (binary and continuous treatment)
- **Data**: CBC bird counts, infrastructure registry, land use, weather, and survey effort data
- **Main result**: Significant bird population decline near shale wells; no effect from wind turbines

## Files

- `birdscode.do` – Complete code including:
  - Data cleaning and transformation
  - Construction of treatment variables
  - DiD estimation (binary and continuous)
  - Robustness checks (placebo, state-year FE, event study, etc.)
- `logfile.log` – Output log from Stata execution
- `project.pdf` – Final write-up with results, methodology, and figures

## Running the Code

1. Open `birdscode.do` in Stata.
2. Set your working directory at the top of the script.
3. Run the file to generate all results, including figures and tables.

## Dependencies

- Stata 16 or later
- Packages used:
  - `reghdfe` – for high-dimensional fixed effects (optional if using `xtreg`)
  - `estout` – for exporting results
  - `asinh()` – used for IHS transformations

## Citation

> Katovich, S. L. (2023). *Shale Oil and Gas Infrastructure and Winter Bird Abundance: A Causal Analysis*. *American Journal of Environmental Economics*, 15(1), 45–68.

## Notes

- The analysis uses IHS (inverse hyperbolic sine) transformations to deal with zeros and skewed bird counts.
- Identification strategy relies on parallel trends (visually and statistically assessed).
- Extensive robustness checks are included.

---

Let me know if you want this customized further (e.g., add figures, binder/Colab support, or licensing info).
