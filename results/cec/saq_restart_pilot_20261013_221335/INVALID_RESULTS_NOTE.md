# Invalidated pre-fix restart pilot

The results in this directory were generated before the restart-candidate write-back fix. `makeRestartPlan` modified a local candidate-pool variable but did not return it to the caller, so the intended restart candidates were not guaranteed to be evaluated. Preserve these files for provenance only; do not use their performance numbers in analysis or claims.

The valid corrected rerun is in:

`results/cec/saq_restart_pilot_20261013_225210`
