# ACS730 Assignment 1 — Multi-environment deployment

## Introduction

I extended the Week 7 Terraform web stack into three AWS Academy environments. The goal was to prove that the same infrastructure change could be tested in dev, applied automatically in staging, and promoted to production through a manual approval gate.

## Terraform and deployment

The shared module in `terraform/modules/web` defines the network, EC2 web server, SSM lookup, and CloudWatch alarm. Dev, staging, and prod use the same module with separate VPC address ranges and distinct S3 state keys. The keys are recorded in `evidence/backend-state-keys.txt`.

PR #13 deployed the initial staging and prod stacks. Staging applied automatically and prod waited for a required reviewer. PR #14 promoted the SSM lookup and CPU alarm after I verified them in dev. The promotion run read each environment's parameter and added one alarm per environment without changing or replacing the existing resources.

- [Initial deployment run](https://github.com/ritulchavda/acs730-coursework/actions/runs/46082604124)
- [SSM and CloudWatch promotion run](https://github.com/ritulchavda/acs730-coursework/actions/runs/46083974580)

## Credentials and production OIDC trust

The workflow used temporary AWS Academy credentials stored as environment secrets in `staging` and `prod`. I verified both environments had all three secrets and removed the repository-level copies. The refresh command for each Academy session is:

```bash
./scripts/refresh-gha-creds.sh ritulchavda/acs730-coursework staging prod
```

In a real AWS account, I would configure the GitHub OIDC provider and attach the following trust policy to the production deployment role. `123456789012` represents the deployment account ID. The Learner Lab restricts IAM changes, so this policy is documented for a real account and the Academy runs used session credentials.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:ritulchavda/acs730-coursework:environment:prod"
        }
      }
    }
  ]
}
```

The federated principal identifies GitHub Actions as the trusted issuer. The `aud` condition rejects tokens intended for a different audience. The exact `sub` condition rejects tokens from other repositories and from jobs outside this repository's `prod` environment. A repository-wide wildcard could let a workflow on another branch request the same production role without entering `prod`. GitHub separately restricts the `prod` environment to `main` and requires reviewer approval. [GitHub OIDC documentation](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)

## Secrets management and observability

I created the placeholder `SecureString` values before running Terraform:

```bash
for env_name in dev staging prod; do
  aws ssm put-parameter --region us-east-1 \
    --name "/acs730/assignment1/$env_name/db-password" \
    --type SecureString --tier Standard \
    --value "$(openssl rand -hex 24)"
done
```

The `aws_ssm_parameter` data source reads the appropriate parameter with decryption disabled, keeping the plaintext value out of Terraform state. The EC2 alarm evaluates average `CPUUtilization` against an 80% threshold over five minutes. The production alarm reached `OK` and showed actual CPU datapoints.

## Recommendation

For a team committed to AWS, I would use AWS CodePipeline and CodeBuild for deployment and keep GitHub as the source repository. I would retain the staged rollout, with an automatic staging deployment and a manual approval before production.

First, I would give staging and production separate build projects and narrowly scoped IAM roles. Each role would have access to its own state key and deployment resources. This removes the manual credential refresh used in Academy. GitHub Actions with OIDC could also eliminate that refresh, so the stronger reason for the AWS-native design is keeping deployment access and role management within the IAM controls the team already operates. [CodeBuild service roles](https://docs.aws.amazon.com/codebuild/latest/userguide/setting-up-service-role.html)

Second, a VPC-enabled CodeBuild job can reach private AWS endpoints for integration tests or deployment verification. The team would still need to configure subnet routing, security groups, and any required outbound access. I would estimate build minutes and network costs before adoption, especially if a NAT gateway is needed for downloading public dependencies. [CodeBuild VPC support](https://docs.aws.amazon.com/codebuild/latest/userguide/vpc-support.html)

Third, CodePipeline supports a manual approval action before the production stage. The team can grant approval rights through IAM and operate the deployment alongside its existing AWS resources and alarms. GitHub Actions would be quicker to retain for a team that mainly works in pull requests and uses public endpoints. For this AWS-only team, private network access and centralized IAM management justify the extra setup. [CodePipeline manual approvals](https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals-action-add.html)

## Conclusion

The promotion run demonstrated that production could receive the same change as staging while retaining a separate approval gate, state key, and credential scope. I destroyed all three environments and deleted the three SSM parameters. The provided cleanup script contained HTML and could not run, so I checked EC2, VPC, CloudWatch, and SSM directly. The four cleanup queries returned empty lists, as recorded in `evidence/destroy-complete.txt`.
