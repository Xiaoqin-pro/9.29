# Candidate-family Q credit assignment check

Protocol: CEC2017 F03/F05/F13/F15/F19/F30, D=30, population=50, 300000 FE, seeds 7--9, fixed MR=0.4, no Recovery, DSS screening, and QFamily candidate actions.

The only change from the old `DSS-QFamily` was reward attribution. The new reward uses Seeking success rate only and gives the existing large reward only when Seeking itself improves the global best. Tracing no longer contributes to the QFamily reward.

| Function | CreditFix MeanError |
|---|---:|
| F03 | 13855.55 |
| F05 | 184.41 |
| F13 | 35918.20 |
| F15 | 1357.39 |
| F19 | 1948.13 |
| F30 | 30151.18 |

CreditFix improves over the old QFamily on 2/6 function means and degrades on 4/6. It is better than fixed Range on 3/6, fixed Hybrid on 2/6, and RandomFamily on 3/6. The result does not support further Q-learning tuning under the current candidate-family design.

This is the pre-specified stopping result for the RL branch. DSS remains the main method; the Q-family variants are retained as diagnostic ablations rather than being promoted as a proven second contribution.
