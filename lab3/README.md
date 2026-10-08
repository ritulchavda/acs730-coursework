# Lab 3

## Overview

This lab uses Terraform and GitHub Actions to create and update an AWS Systems Manager (SSM) parameter. Terraform state is stored in an S3 bucket with versioning and state locking enabled.

## Terraform Version

Terraform version used: **1.10.3**

## GitHub Actions Workflows

- **lab3-ci.yml:** Checks shell script syntax on pull requests without AWS credentials.
- **lab3-deploy.yml:** Runs Terraform plan on pull requests and applies changes only on pushes to `main`. Concurrency control prevents overlapping deployments.

## AWS Credentials and OIDC

The Vocareum workstation uses temporary credentials from its LabRole instance profile. The `refresh-gha-creds.sh` script copies the session credentials into GitHub Actions secrets and sets the `AWS_REGION` repository variable.

In production, OIDC is preferred because it provides temporary AWS credentials without storing access keys. OIDC cannot be configured in this Academy environment because the required IAM permissions are denied. Temporary session credentials must be refreshed when the lab session expires.

## Troubleshooting

- **ExpiredToken:** Start a new lab session and rerun `refresh-gha-creds.sh`.
- **Missing aws-region:** Set the `AWS_REGION` repository variable to `us-east-1`.
- **NoSuchBucket:** Verify the S3 bucket name in `main.tf`.
- **Unexpected 1 to add:** Check that the workstation and GitHub Actions use the same S3 backend.

## Deployment Evidence

The successful GitHub Actions apply should report:

`Apply complete! Resources: 0 added, 1 changed, 0 destroyed.`

The SSM parameter should contain `hello from GitHub Actions`. Save the successful run details in `lab3/evidence/apply-run.json`.

## Experiments

### Experiment 1: Expired Credentials

**Prediction:** Expired session credentials cause AWS authentication to fail.

**Observation:** Refreshing credentials after starting a new lab session allows the workflow to run again without changing repository configuration.

### Experiment 2: Removing the Backend

**Prediction:** Without the shared S3 backend, GitHub Actions may propose creating a duplicate resource because it cannot access the workstation's local state.

**Observation:** Local state is not shared with GitHub-hosted runners, demonstrating why remote state is necessary.

_Update these observations to match your actual experiment results._

## Cleanup

Run `terraform destroy` to remove the SSM parameter, then run `./scripts/cleanup-check.sh`. Keep the S3 state bucket for future labs.

## Conclusion

This lab demonstrates infrastructure automation using Terraform, remote state management, GitHub Actions deployment controls, temporary AWS credentials, and responsible cloud resource cleanup.
