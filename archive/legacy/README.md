# Historical implementation archive

This folder preserves the exploratory MATLAB drivers, baseline adapters,
experimental switches, and the original UAV entry point. Their names and
historical labels are intentionally unchanged so old result snapshots remain
traceable. They are not the frozen paper implementation.

Use `setup_project(true)` to add this folder after `src` when reproducing an
old experiment. New work should call the formal implementation in `src`.

The archived files were moved without changing their algorithm bodies. Some
old drivers assume they are launched from the repository root; use the
original commit or result snapshot when exact historical reruns are required.
