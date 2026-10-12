# Confirmation analysis witnesses

The exact conditional signed-rank implementation was evaluated against four hand-checkable cases before interpreting confirmation results:

- Ten nonzero differences with the same sign: two-sided p = 2 / 2^10 = 0.001953125.
- Negating all those differences: unchanged p.
- Four tied absolute differences with two positive and two negative signs: p = 1.
- All differences zero: p = 1, zero nonzero pairs.

This verifies zero removal, tied midranks, symmetry and the finite conditional sign-flip distribution. Holm-adjusted values are published next to raw p values. A nonsignificant difference does not imply noninferiority.
