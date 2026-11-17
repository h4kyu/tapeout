# Consolidated poker area measurements

Consolidated on 2026-11-17 from baseline `989fd40`, using separate implementation
commits. Baseline and fixed-slot reference runs are from 2026-11-16. The source
experiments and their compatibility notes remain available
in [the standalone review](https://github.com/h4kyu/tapeout/blob/opt/derived-payout/docs/potential-optimizations.md).
No documentation-only observation commits were cherry-picked.

## Measurement method

All comparisons use the unchanged 1x1 tile, GF180MCU D PDK, 40 ns clock period
(25 MHz), and the repository's GDS/precheck/gate-level/viewer workflow.
The retained-output comparison uses the exact `project.v`, `vga.v`, `info.yaml`,
and `test/Makefile` configuration from `9451a78`, on measurement branches only.
That branch has an inactive VGA shell and `keep` attributes on all display-facing
game outputs; it is not a functioning renderer. `dealt_mask` remains unconnected.

Read these values from each linked run's **GDS_logs** artifact:

- Utilization: `*-openroad-globalplacement/openroad-globalplacement.log`, the
  `GPL-0019` percentage. This is the placement metric used in the original
  68.086% baseline, not the final utilization including physical cells.
- Cells: `*-openroad-rcx/or_metrics_out.json`,
  `design__instance__count__class:standard_cell`. This reproduces the published
  baseline of 1,462 and excludes physical fill/tap/endcap cells and tie cells.
- Wire length: `final/metrics.csv`, `route__wirelength`, in micrometres.
- Final extracted timing: `*-openroad-stapostpnr/state_out.json`, `metrics`.
  Nominal setup/hold use `timing__{setup,hold}__ws__corner:nom_tt_025C_3v30`.
  Worst setup/hold are the minimum across all nine characterized corners,
  `timing__{setup,hold}__ws`. Worst setup is at `max_ss_125C_3v00` and worst hold
  at `min_ff_n40C_3v60` except status-only D, which is at `max_ff_n40C_3v60`.
  Positive slack is margin;
  negative setup slack is a violation. Zero-clipped WNS is not used for hold.

The machine-readable [measurement record](measurements/combined-area.json)
preserves exact revisions, run URLs, unrounded values, every setup/hold corner,
and final CI outcomes. The workflow's green status does not establish timing
closure at every corner: the original baseline already has -6.295 ns slow-corner
setup slack at 25 MHz.

## Regression coverage

All decorated tests are imported in `test/test.py`. Coverage retains all 52
valid and 12 invalid card codes from the rejected direct-mask experiment;
duplicate and discarded-card rejection; all 32 hold masks; full ten-card list
rejection and reuse after a new deal; reset during deal/draw; balance eligibility
at 0 through 6 and 65,535; exact saturation, overflow, zero payout, and exactly-once
crediting; and displayed-payout category mapping, stability, new-deal clearing,
and asynchronous reset. Useful straight-window/permutation and 1,000 random raw
card-code cases were adapted from the rejected multicycle experiment, alongside
the existing 3,000 random valid hands against the Python reference.

The evaluator remains combinational with one EVALUATE controller cycle. Production
debounce remains 500,000 cycles. Gate-level CI checks the synthesized wrapper's
reset/status pins; standalone core/evaluator gameplay instances use RTL even in
that job. Green gate-level CI is not full gate-level gameplay coverage.

## Status-only wrapper

| Revision / run | Utilization | Cells | Wire (µm) | Nominal setup / hold (ns) | Worst setup / hold (ns) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline [`989fd40`](https://github.com/h4kyu/tapeout/actions/runs/43896181617) | 68.086% | 1,462 | 66,630 | 17.461 / 0.600 | -6.295 / 0.227 |
| Fixed slots (standalone reference) [`fab934a`](https://github.com/h4kyu/tapeout/actions/runs/43902056794) | 64.121% | 1,320 | 53,934 | 18.224 / 0.622 | -4.809 / 0.240 |
| A: fixed slots + shared ranks [`9357a1f`](https://github.com/h4kyu/tapeout/actions/runs/44135352831) | 64.966% | 1,386 | 75,221 | 15.772 / 0.595 | -9.736 / 0.223 |
| B: A + used-card list [`c9c6130`](https://github.com/h4kyu/tapeout/actions/runs/44135828537) | 61.988% | 1,267 | 47,352 | 19.303 / 0.585 | -2.379 / 0.220 |
| C: B + shared adder (excluded) [`c6623fc`](https://github.com/h4kyu/tapeout/actions/runs/44136699530) | 61.863% | 1,263 | 49,658 | 14.647 / 0.585 | -4.528 / 0.220 |
| D: B + derived payout (selected) [`dea1a33`](https://github.com/h4kyu/tapeout/actions/runs/44137624373) | 63.129% | 1,300 | 56,415 | 16.571 / 0.576 | -4.761 / 0.213 |

## Retained VGA-facing outputs

| Revision / run | Utilization | Cells | Wire (µm) | Nominal setup / hold (ns) | Worst setup / hold (ns) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Retained VGA baseline [`9451a78`](https://github.com/h4kyu/tapeout/actions/runs/43894926379) | 75.354% | 1,546 | 90,701 | 15.114 / 0.589 | -11.455 / 0.221 |
| Retained VGA A [`6d29967`](https://github.com/h4kyu/tapeout/actions/runs/44137871013) | 73.711% | 1,507 | 82,051 | 16.421 / 0.642 | -8.835 / 0.250 |
| Retained VGA B [`70cafac`](https://github.com/h4kyu/tapeout/actions/runs/44136852638) | 70.813% | 1,404 | 57,171 | 18.595 / 0.577 | -3.983 / 0.214 |
| Retained VGA C (candidate only) [`f4470f9`](https://github.com/h4kyu/tapeout/actions/runs/44137914884) | 69.675% | 1,382 | 57,232 | 18.481 / 0.617 | -3.916 / 0.237 |
| Retained VGA D (selected RTL) [`9547201`](https://github.com/h4kyu/tapeout/actions/runs/44137722092) | 65.796% | 1,323 | 50,357 | 15.725 / 0.610 | -4.381 / 0.232 |

## Selection and incremental effects

- Keep fixed writes, shared combinational ranks, and the used-card list. B versus
  A saves 2.978 utilization points, 119 cells, and 27,869 µm of wire (37.05%),
  while improving worst setup slack by 7.358 ns. The retained-output comparison
  also favors the list: 2.898 points, 103 cells, and 24,880 µm less wire.
- Exclude shared balance arithmetic from this branch. C versus B saves only
  0.125 points and four cells but adds 2,306 µm of wire (4.87%) and loses
  2.150 ns of worst setup slack and 4.656 ns nominal setup slack.
  Its retained-output run is more promising: 1.138 points and 22 fewer cells,
  only 61 µm more wire, and 0.067 ns better worst setup slack. Reconsider it with
  the actual renderer and derived payout; C plus D has not been measured, and
  their individual results must not be added.
- Keep derived payout as the requested separate cleanup, with its actual cost
  visible. D versus B in the status-only wrapper adds 1.141 utilization points,
  33 cells, and 9,063 µm of wire, and loses 2.382 ns worst setup slack.
  With display-facing outputs retained, D versus B saves 5.017 points, 81 cells,
  and 6,814 µm of wire (11.92%), while worst setup slack worsens by 0.398 ns.
  The displayed lookup is combinational; all sequential payout assignments are
  removed, while balance crediting still uses the evaluator payout.
- The selected status-only D improves on baseline by 4.957 utilization points
  (7.28% relative), 162 cells (11.08%), and 10,215 µm of wire (15.33%).
  Retained-output D improves on its own baseline by 9.558 points (12.68%),
  223 cells (14.42%), and 40,344 µm of wire (44.48%).
- Keep the direct-mask and multicycle implementations excluded. Their useful
  representation-independent tests were carried separately. The selected code
  retains exactly one used-card representation and the combinational evaluator.
- Neither configuration closes setup timing at every characterized corner at
  25 MHz. Selected worst setup is -4.761 ns in the current wrapper and -4.381 ns
  with retained outputs; hold slack remains positive in every measured corner.
  All-corner closure remains required before signoff.

## Commit separation

| Delivered change | Integration commit | Source |
| --- | --- | --- |
| Fixed card-slot writes | `e03cb0a` | `fab934a` |
| Shared rank comparisons | `9357a1f` | `db260f4` |
| Card-code and balance boundary tests only | `62b05c6` | Tests from `08788d4` and `956ad73` |
| Used-card list, resolved with fixed writes | `c9c6130` | `b88aa25` |
| Additional evaluator data coverage only | `8df0383` | Adapted tests from `e6e9840` |
| Derived displayed payout | `dea1a33` | `36d6d17` |

The shared-adder implementation remains isolated at `c6623fc`.
VGA configuration commits exist only on `measure/combined-area-vga-*` branches;
the delivery branch does not change `project.v`, `info.yaml`, the flow config,
or the testbench source list.

## CI outcomes

All eleven linked physical runs completed successfully, with successful `gds`,
`precheck`, `gl_test`, and `viewer` jobs. The exact measured revisions also passed
RTL and documentation CI. This includes the rejected shared-adder candidate.

| Revision | RTL suite | RTL CI | Docs CI | GDS / precheck / GL / viewer |
| --- | ---: | --- | --- | --- |
| `989fd40` | 14/14 | [pass](https://github.com/h4kyu/tapeout/actions/runs/43896181737) | [pass](https://github.com/h4kyu/tapeout/actions/runs/43896181601) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/43896181617) |
| `fab934a` | 14/14 | [pass](https://github.com/h4kyu/tapeout/actions/runs/43902056747) | [pass](https://github.com/h4kyu/tapeout/actions/runs/43902056694) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/43902056794) |
| `9357a1f` | 14/14 | [pass](https://github.com/h4kyu/tapeout/actions/runs/44135352792) | [pass](https://github.com/h4kyu/tapeout/actions/runs/44135352811) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/44135352831) |
| `c9c6130` | 17/17 | [pass](https://github.com/h4kyu/tapeout/actions/runs/44135828195) | [pass](https://github.com/h4kyu/tapeout/actions/runs/44135828214) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/44135828537) |
| `c6623fc` | 17/17 | [pass](https://github.com/h4kyu/tapeout/actions/runs/44136699504) | [pass](https://github.com/h4kyu/tapeout/actions/runs/44136699605) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/44136699530) |
| `dea1a33` | 18/18 | [pass](https://github.com/h4kyu/tapeout/actions/runs/44137623912) | [pass](https://github.com/h4kyu/tapeout/actions/runs/44137623975) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/44137624373) |
| `9451a78` | 14/14 | [pass](https://github.com/h4kyu/tapeout/actions/runs/43894926224) | [pass](https://github.com/h4kyu/tapeout/actions/runs/43894926314) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/43894926379) |
| `6d29967` | 16/16 | [pass](https://github.com/h4kyu/tapeout/actions/runs/44137870761) | [pass](https://github.com/h4kyu/tapeout/actions/runs/44137870699) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/44137871013) |
| `70cafac` | 17/17 | [pass](https://github.com/h4kyu/tapeout/actions/runs/44136852281) | [pass](https://github.com/h4kyu/tapeout/actions/runs/44136852210) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/44136852638) |
| `f4470f9` | 17/17 | [pass](https://github.com/h4kyu/tapeout/actions/runs/44137914714) | [pass](https://github.com/h4kyu/tapeout/actions/runs/44137914818) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/44137914884) |
| `9547201` | 18/18 | [pass](https://github.com/h4kyu/tapeout/actions/runs/44137721860) | [pass](https://github.com/h4kyu/tapeout/actions/runs/44137721844) | [all pass](https://github.com/h4kyu/tapeout/actions/runs/44137722092) |

Stage A was also rerun locally after the independent card-code and balance tests
were imported at `62b05c6`: 16/16 passed before list integration. Additional
straight-window/raw-code coverage at `8df0383` keeps the suite count at 17.
The selected implementation passes 18/18 locally and Verilator lint with the
pre-existing wrapper-filename and intentionally unconnected-pin warnings excluded.
The final documentation commit changes no RTL; its final branch CI outcomes are
recorded on the delivery PR.

