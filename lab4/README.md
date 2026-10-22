# ACS730 Lab 4 — Docker and CI/CD Pipeline

## 1. Docker Image Size

| Image | Base Image | Image Size |
|---|---|---:|
| `acs730-lab4:baseline` | `python:3.12-slim-bookworm` | 130 MB |

The Docker image was built successfully using the `python:3.12-slim-bookworm` base image.

### Layer Observations

- The base image contains the largest layers, including approximately 74.9 MB, 40.3 MB, and 8.52 MB layers.
- The Python package installation layer is approximately 6.38 MB.
- The application code layer is approximately 285 bytes.
- Docker layer caching allows unchanged layers to be reused during subsequent builds.

## 2. Docker Build Timing and Cache Evaluation

The following timings were measured on the EC2 instance using `time docker build`.

| Build Type | Elapsed Time |
|---|---:|
| Build with `--no-cache` | 5.122 seconds |
| Cached build | 0.247 seconds |
| Subsequent cached build | 0.239 seconds |

### Cache Evaluation

The build with `--no-cache` took 5.122 seconds, while the cached builds took approximately 0.24 seconds. This shows that Docker layer caching significantly reduced build time when the existing layers could be reused.

These are local EC2 Docker build timings, not GitHub Actions workflow timings.

## 3. Why GHCR Uses SHA Tags Instead of `latest`

A Git commit SHA provides a unique identifier for the source code used to build a Docker image. This makes it easier to identify, reproduce, and roll back to a specific build.

The `latest` tag can point to different images over time, so it does not reliably identify a particular version. SHA-based tags provide better traceability in a CI/CD pipeline.

## 4. Composite Action and Reusable Workflow

A composite action is useful for grouping related steps, such as setting up Python and installing dependencies, so they can be reused within jobs.

A reusable workflow is suitable for a complete job or workflow, such as building and publishing a Docker image. It can define its own runner, inputs, outputs, and permissions.

## 5. GitHub Actions vs. AWS-Native Services

| Feature | GitHub Actions | AWS-Native Services |
|---|---|---|
| CI/CD orchestration | GitHub Actions workflows | AWS CodePipeline |
| Build execution | GitHub-hosted or self-hosted runners | AWS CodeBuild |
| Container image storage | GitHub Container Registry (GHCR) | Amazon Elastic Container Registry (ECR) |
| Credentials | GitHub tokens and configured secrets | AWS IAM roles and policies |

GitHub Actions integrates directly with a GitHub repository and supports automated testing and image publishing. AWS-native services integrate closely with AWS resources and IAM permissions. In an AWS Academy environment, restrictions on IAM permissions may limit which AWS-native operations can be configured.

## 6. Experiments

### Experiment 1: Docker Layer Caching

**Prediction:** I expected a Docker build using cached layers to finish faster than a build using `--no-cache`.

**Run:** I built the image using `docker build --no-cache -t acs730-lab4:no-cache ./lab4` and then performed cached builds. The no-cache build took 5.122 seconds, while the cached builds took 0.247 seconds and 0.239 seconds.

**Explanation:** Docker reused existing layers during the cached builds, avoiding the need to repeat operations such as installing Python dependencies. As a result, the cached builds completed much faster than the no-cache build.

### Experiment 2: Dockerfile Layer Order

**Prediction:** I expected that changing the order of Dockerfile instructions would affect how effectively Docker could reuse cached layers.

**Run:** Change the Dockerfile so that application code is copied before the dependency installation step, then build the image again after making a small change to `app.py`. Compare the build time with the original Dockerfile.

**Explanation:** When application code is copied before dependencies are installed, a change to the application may invalidate the cache for subsequent instructions. Keeping dependency installation before copying frequently changed application code generally allows Docker to reuse the dependency layer and reduce rebuild time.
