# Lab 5 evidence

All Terraform plans, applies and experiments below targeted LocalStack at `http://localhost:4566`. The only real-AWS call was the read-only, tag-filtered VPC cleanup check; it returned `[]`.

| Requirement | Evidence |
|---|---|
| Initial green PR run, both jobs | [Run 42259486992](https://github.com/ritulchavda/acs730-coursework/actions/runs/42259486992), `green-run.json`, `green-run.log` |
| Deliberate failure | [Run 42259902646](https://github.com/ritulchavda/acs730-coursework/actions/runs/42259902646), `failed-run.json`, `failed-run.log`; validation fails on undeclared `var.vpc_cdir`, LocalStack is skipped |
| Disabled merge button | `required-check-blocked.png`, captured by the user on PR #12 while the deliberate break was active |
| Required checks block merge | `pr-blocked.json` reports `mergeStateStatus: BLOCKED`; `branch-protection.json` lists both required lab5 checks |
| Fixed configuration passes again | [Run 42260147827](https://github.com/ritulchavda/acs730-coursework/actions/runs/42260147827), `restored-run.json`, `restored-run.log` |
| Run sequence | `ci-runs.txt` shows the initial pass, deliberate failure and restored pass, newest first |
| Local apply and repeat plan | `local-apply.txt` (10 added), `local-no-change.txt` (no changes), `local-outputs.txt` (LocalStack target) |
| Local teardown | `local-destroy.txt` (10 destroyed), `describe-vpcs-after-destroy.json` (no `10.42.0.0/16`) |
| Real-AWS cleanup check | `real-aws-lab5-vpcs.json` (empty tag-filtered result) |
| Experiments | `experiment-no-depends-on.txt`, `experiment-bucket-*.txt`; predictions and interpretation are in the lab README |
| Preflight | `validate.txt`, `preflight.txt` (4 passed, 0 failed, 0 missing) |

The screenshot includes unrelated failing Lab 3/4 checks because those older workflows run on every PR. The Lab 5 failure is independently recorded in its workflow log and JSON. The required Lab 5 jobs pass after the deliberate typo is repaired. No bypass is used to merge the PR.

The inherited midterm starter state blob predates Lab 5; see the history note in the lab README. No state file, plan file, private key or provider installation is part of this lab submission.
