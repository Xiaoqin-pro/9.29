# V4.1 screening ablation

This development ablation uses the V4.1 no-Recovery protocol, fixed MR=0.4 for the screening comparison, D=30, population=50, 300000 FE, six functions (F3, F5, F13, F15, F19 and F30), and three paired seeds. Four workers were used for all 90 runs.

Configurations:
- `ModeBudget-NoScreen`: mode-preserving FE allocation, without cat or candidate spatial screening.
- `ModeBudget-SS`: mode-preserving allocation with cat-level screening, but no Seeking candidate-level screen.
- `DSS-CSO`: mode-preserving allocation with cat-level and Seeking candidate-level screening.
- `DSS-Random`: DSS with random three-action MR scheduling.
- `DSS-Q`: DSS with 27-state Q-learning MR scheduling.

The total FE budget was filled in every run and mode allocation error was zero. The no-screen configuration is much worse on the difficult functions. Cat-level screening gives a large improvement, and the second candidate-level screen improves the cat-screened mean on 5/6 functions. This supports the structural role of DSS.

DSS-Q is not uniformly better than fixed MR=0.4: in this same protocol it improves F15 and F19 but loses on the other four functions. Therefore the current evidence supports DSS as the stronger contribution, while the Q-learning scheduler remains an optional module requiring broader validation.

Only CSV and README files are intended for repository upload. MATLAB `.mat` histories remain local.
