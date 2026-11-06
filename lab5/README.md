# Lab 5 - Week 6: Terraform network and LocalStack CI

Owner: `rschavda1`. Terraform CLI: **1.10.3**. AWS provider: **5.100.0**, locked in `.terraform.lock.hcl` within the `~> 5.60` constraint. LocalStack: **3.8.1** from the `localstack/localstack:3.8` image.

## What I built

One configuration selects real AWS or LocalStack using `use_localstack`. It creates a DNS-enabled VPC (`10.42.0.0/16`), two public subnets, an internet gateway, a route table with a default internet route, one association per subnet, and a security group with dynamic HTTP ingress. An EC2 instance installs nginx with `user_data`; an optional S3 bucket is enabled in the LocalStack variable file.

The region and availability-zone data sources resolve target information. Real AWS also uses an Amazon-owned Amazon Linux 2023 AMI lookup, gated off in LocalStack; only the emulator uses the placeholder AMI variable. Every VPC, subnet, gateway and security-group connection uses an attribute reference. The public subnets and internet gateway avoid the NAT gateway cost highlighted in the course's fixed $50 budget.

The instance references its subnet and security group, so Terraform infers those dependencies. It does not reference the route-table associations. Explicit `depends_on` waits for routing before the instance boots and `dnf` needs internet access. `user_data_replace_on_change = true` makes later bootstrap edits rebuild the instance so the script runs again.

## Run safely against LocalStack

Run from the repository root on the EC2 workstation:

```bash
docker run -d --name acs730-lab5-localstack \
  -p 127.0.0.1:4566:4566 -e SERVICES=ec2,s3,sts,iam localstack/localstack:3.8
for i in $(seq 1 30); do
  curl -fsS http://localhost:4566/_localstack/health && break
  sleep 5
done
cd lab5
terraform init -input=false
terraform fmt -check -recursive
terraform validate
terraform plan -input=false -var-file=localstack.tfvars -out=tfplan
terraform apply -input=false -auto-approve tfplan
terraform output
```

Always supply `-var-file=localstack.tfvars` to plan and destroy. `use_localstack` defaults to **false**: forgetting the file can target real AWS using the workstation's credentials. Inspect the saved plan's `provider_target`, which must say `localstack (http://localhost:4566)`, before applying. Apply the saved plan itself, without another variable file. Its public IP and URL are simulated; LocalStack does not boot nginx or serve that URL.

Teardown and verify while the emulator is still running:

```bash
terraform destroy -input=false -auto-approve -var-file=localstack.tfvars
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_EC2_METADATA_DISABLED=true \
  aws --endpoint-url=http://localhost:4566 --region us-east-1 \
  ec2 describe-vpcs --output json | tee evidence/describe-vpcs-after-destroy.json
docker rm -f acs730-lab5-localstack
```

The default LocalStack VPC may remain; the lab's `10.42.0.0/16` must be absent. No real AWS resources are needed for this lab. To target real AWS deliberately, use a separate state/work directory, omit the LocalStack file, supply `-var=owner=rschavda1`, and review the target and costs before applying.

## Why for_each here and count there

Subnets have distinct, stable identities (`a`, `b`), so `for_each` creates addresses such as `aws_subnet.public["a"]`. Adding a new key `c` adds a subnet and its route-table association without replacing `a` or `b`. Removing an unused `c` removes only that subnet and association. Removing the first subnet also moves/replaces the web instance because it deliberately selects the first sorted key.

With `count` and an ordered CIDR list, removing the middle entry shifts later indexes: Terraform compares the old subnet at `[1]` with a different CIDR now at `[1]`, requiring replacement as well as destroying the final index. `for_each` avoids that identity shift.

The bucket is a yes/no choice about one resource, so `count = var.create_artifact_bucket ? 1 : 0` is appropriate. With everything already applied, switching it off plans `0 to add, 0 to change, 1 to destroy`; switching it back on plans `1 to add, 0 to change, 0 to destroy`. `one(aws_s3_bucket.artifacts[*].bucket)` safely yields null when the count is zero; indexing `[0]` would fail on the empty collection. Root outputs with null values are omitted by `terraform output`.

## CI and required checks

The root workflow `.github/workflows/lab5-ci.yml` is scoped to `lab5/**` and its own workflow file on pull requests and pushes to `main`. The `fmt and validate` job runs formatting first, then credential-free initialization with no backend, validation and a state-history guard. The `plan and apply against LocalStack` job has `needs: gates`; it starts a LocalStack service container, waits for readiness, plans with `localstack.tfvars`, applies the saved plan, checks outputs and destroys resources even if a previous step failed.

The workflow reads no repository AWS secrets, has no credential setup action and requests only `contents: read`. The provider's literal `test` values are dummy emulator inputs. EC2, S3, STS and IAM endpoints are overridden together, metadata/credential/account/region checks are skipped only in emulator mode, and S3 path-style addressing is enabled there.

Both lab5 job names must be required checks on `main`. The deliberate break changes `var.vpc_cidr` to undeclared `var.vpc_cdir`: formatting still passes, validation fails, and the dependent LocalStack job is skipped. Fixing the spelling restores both checks. Evidence records the failing and passing run URLs, jobs, commit hashes and the blocked merge status.

Repository-history note: the imported midterm starter commit `8fe737a` included `midterm-practice/terraform/terraform.tfstate`, removed in `5929081` before this lab. The course helper already exempts practice folders. This workflow allows only that exact pre-existing blob (`5e72dea8be294de7cffea3e47e3a782b89638c55`) at that path and fails for any other state blob, including a changed file at the same path. It does not rewrite earlier coursework history. A grader that rejects every historical state file without the template exception may still flag that inherited file.

## Why not plan and apply against real AWS on every pull request

Each PR apply creates billable infrastructure and each teardown takes time. Repeating that loop across students and pushes consumes a fixed Academy credit allowance without demonstrating more about HCL structure. Instances, public IPv4 addresses, storage and especially unnecessary NAT gateways can continue charging when a failed run misses cleanup.

Real cloud APIs introduce minutes of provisioning and deletion, throttling, eventual consistency and transient failures unrelated to a code change. Concurrent PRs can collide on bucket names, resource names or shared state. Review becomes slower and people start ignoring failures that appear unrelated to their changes.

Academy makes authentication harder: LabRole session credentials expire after hours, so an unchanged PR can fail when a session ends. IAM restrictions can prevent creating a narrowly scoped CI role or configuring OIDC. Copying session credentials into repository secrets adds refresh and exposure risks; it does not make those credentials long-lived. Outside Academy, OIDC with a least-privilege role is preferable to stored AWS access keys, but it does not eliminate deployment cost or provisioning delays.

LocalStack gives each CI job a disposable, isolated account without real AWS credentials or resource charges. A green run shows the Terraform configuration, references and supported API calls are coherent. It does **not** validate IAM permissions, current AWS quotas, AMI bootability, actual internet connectivity or execution of `user_data`. A controlled real-AWS integration check after merge or on a schedule can cover those gaps with scoped access, reviewed costs and reliable cleanup.

## Experiments

### 1. Remove depends_on, plan only

Prediction: removing the explicit routing dependency from an already applied configuration will produce no resource changes because the dependency controls ordering rather than resource attributes. Observation: the plan reported **No changes**, and the dependency was restored. LocalStack cannot expose the real boot-time race because it does not execute the instance's `dnf` commands; a no-change plan does not prove bootstrapping is safe.

### 2. Turn the bucket off, then restore it

Prediction: setting `create_artifact_bucket=false` destroys only `aws_s3_bucket.artifacts[0]`; `one(...)` returns null, while a root output with that value disappears. Observation: the plan and apply removed exactly one bucket, `terraform console -plan` printed `null`, and requesting the named root output returned an output-not-found error. Restoring true planned and created exactly one bucket; the input file and resource configuration were left restored before final teardown.

## Validation and evidence

The workstation apply created **10 resources**, a repeated plan reported **No changes**, and final destroy removed **10 resources**. The post-destroy JSON contains only LocalStack's default VPC and no lab CIDR. `evidence/` contains only the required passing/failing CI records, blocked-merge screenshot, `pr-blocked.json`, `ci-runs.txt` and `describe-vpcs-after-destroy.json`.

The PDF walkthrough's `skip_requester_charged` spelling is not an AWS provider option; this implementation uses `skip_requesting_account_id`. The Owner value is a quoted HCL string. `.terraform.lock.hcl` is committed; `.terraform/`, `*.tfstate`, state backups, crash reports and saved plans are ignored.
