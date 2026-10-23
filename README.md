# Bookinfo Docker Image Optimization & CI/CD

[![Docker CI/CD](https://github.com/saiwaiyan09/bookinfo-docker-cicd/actions/workflows/docker-build-push.yml/badge.svg)](https://github.com/saiwaiyan09/bookinfo-docker-cicd/actions/workflows/docker-build-push.yml)

A hands-on Docker and GitHub Actions project that compares **three image-build approaches** across **four Istio Bookinfo microservices**, benchmarks the results, and automatically builds and publishes all **12 image variants** to Docker Hub.

> **Scope:** Container image builds, optimization experiments, benchmarking, and CI/CD automation. This repository does **not** deploy or run the Bookinfo application. MongoDB and MySQL images are outside the project scope.

## Project objectives

- Explore how Dockerfile changes affect image size and build time.
- Compare original, updated, and optimized Dockerfiles using consistent local benchmarks.
- Publish images to Docker Hub with clear service and variant tags.
- Automate builds and publication using a GitHub Actions matrix and Docker Buildx.
- Use GitHub Actions caching, image digests, and compressed-layer-size reporting.
- Document results accurately, including cases where an attempted optimization is not an improvement.

## Services and image variants

| Service | Application technology | Variants |
| --- | --- | --- |
| `productpage` | Python 3.13 | `original`, `updated`, `optimized` |
| `details` | Ruby 3.4 | `original`, `updated`, `optimized` |
| `ratings` | Node.js (original: 23; updated/optimized: 24) | `original`, `updated`, `optimized` |
| `reviews` | Gradle / Java 8 build stage; Open Liberty / Java 17 runtime | `original`, `updated`, `optimized` |

Each service directory contains three Dockerfile variations:

```text
<service>/
├── Dockerfile            # Original approach
├── Dockerfile.updated    # Updated base image / dependencies, as applicable
└── Dockerfile.optimized  # Alternative optimization experiment
```

The precise changes differ by service; an `optimized` filename denotes an experiment, **not a guarantee of smaller images or faster builds**.

## CI/CD architecture

```text
                Developer / GitHub
                        │
           Push to main / Pull request
                 Manual dispatch
                        │
                        ▼
                 GitHub Actions
                        │
             Matrix: 4 services × 3
                        │
                        ▼
                Docker Buildx
                GitHub Actions
                 layer cache
                        │
             ┌──────────┴──────────┐
             │                     │
       Pull request         Push to main /
       build only           manual dispatch
             │                     │
             ▼                     ▼
        Validate build       Build and push
                                   │
                                   ▼
                               Docker Hub
                                   │
                                   ▼
                       Inspect compressed layer
                       size and image digest
                                   │
                                   ▼
                         GitHub job summary
```

The workflow lives at [`.github/workflows/docker-build-push.yml`](.github/workflows/docker-build-push.yml).

**Workflow behavior:**

- `push` to `main`: builds and publishes all 12 tags.
- `pull_request` to `main`: builds without publishing.
- `workflow_dispatch`: allows a manual run; non-PR runs publish tags.
- `max-parallel: 3`: limits concurrent matrix jobs.
- `cache-from` / `cache-to`: uses a separate GitHub Actions cache scope for each service/variant.
- A successful publish is followed by image-digest and **compressed layer size** reporting.

Docker Hub authentication uses the repository secret `DOCKERHUB_TOKEN`. **Do not commit access tokens or credentials.**

## Local benchmark results

The following values are recorded from the project's local build experiments. Build times reflect the tested local environment; they are **not** the same metric as GitHub Actions' cached build-and-push duration.

| Service | Variant | Local build time (s) | Reported disk usage (MB) | Reported content size (MB) |
| --- | --- | ---: | ---: | ---: |
| productpage | original | 57.06 | 287 | 67.9 |
| productpage | updated | 49.29 | 283 | 66.7 |
| productpage | optimized | 30.97 | 288 | 67.6 |
| details | original | N/A | 288 | 81.8 |
| details | updated | 15.40 | 287 | 82.0 |
| details | optimized | 13.55 | 255 | 74.3 |
| ratings | original | 21.70 | 370 | 88.8 |
| ratings | updated | 21.91 | 373 | 89.9 |
| ratings | optimized | 11.58 | 359 | 87.7 |
| reviews | original | 52.76 | 566 | 167 |
| reviews | updated | 43.72 | 601 | 183 |
| reviews | optimized | 48.09 | 670 | 203 |

`N/A` indicates that a reliable local build-time measurement was not recorded. Local disk usage, locally reported content size, and the compressed-layer-size metric in CI are distinct measurements and should **not** be compared as if they were equivalent.

### Observations

- **Productpage:** The optimized experiment had the shortest measured local build time (30.97 s), but its disk usage (288 MB) was slightly **higher** than the original (287 MB).
- **Details:** The optimized variant had the smallest recorded disk usage (255 MB), compared with 288 MB for the original.
- **Ratings:** The optimized variant reduced the measured local build time to 11.58 s and disk usage to 359 MB, compared with 21.70 s and 370 MB for the original.
- **Reviews:** The optimized experiment **increased** disk usage to 670 MB, versus 566 MB for the original. This is an important negative result and a candidate for further investigation rather than a successful size optimization.

These are measurements from a specific environment, not universal performance claims. Repeated runs and controlled cache conditions would be needed for stronger conclusions.

## Pull benchmark results

Pull timings were also recorded for the image variants. The first timing set used a cached environment; the second was collected after cleaning local Bookinfo tags and Buildx cache. Shared image layers and registry/network effects mean these figures should **not** be described as strictly isolated cold-pull times.

| Service | Variant | Earlier pull (s) | Post-cleanup pull (s) |
| --- | --- | ---: | ---: |
| productpage | original | 3.259 | 8.685 |
| productpage | updated | 3.138 | 8.319 |
| productpage | optimized | 3.096 | 8.099 |
| details | original | 2.928 | 6.856 |
| details | updated | 3.041 | 7.150 |
| details | optimized | 3.106 | 6.197 |
| ratings | original | 3.096 | 7.006 |
| ratings | updated | 3.136 | 7.905 |
| ratings | optimized | 2.998 | 6.717 |
| reviews | original | 2.894 | 9.410 |
| reviews | updated | 3.347 | 10.495 |
| reviews | optimized | 3.032 | 12.124 |

The tracked benchmark files include [`benchmarks/pull-results-cached.csv`](benchmarks/pull-results-cached.csv) and [`benchmarks/pull-results-post-cleanup.csv`](benchmarks/pull-results-post-cleanup.csv).

## Reproduce a Docker image build

From the repository root, choose a service and Dockerfile variant:

```bash
# Original image
docker build -f productpage/Dockerfile -t bookinfo-productpage:original ./productpage

# Updated image
docker build -f productpage/Dockerfile.updated -t bookinfo-productpage:updated ./productpage

# Optimized image
docker build -f productpage/Dockerfile.optimized -t bookinfo-productpage:optimized ./productpage
```

Repeat the same pattern for `details`, `ratings`, or `reviews`. Docker commands above **only build images**; they do not start containers or deploy the application.

For a local build-time experiment, optionally use `--no-cache` and an external timer, and record the machine, Docker version, network conditions, and cache policy alongside the result.

## Docker Hub images

Published repositories:

- [bookinfo-productpage](https://hub.docker.com/r/saiwaiyan09/bookinfo-productpage)
- [bookinfo-details](https://hub.docker.com/r/saiwaiyan09/bookinfo-details)
- [bookinfo-ratings](https://hub.docker.com/r/saiwaiyan09/bookinfo-ratings)
- [bookinfo-reviews](https://hub.docker.com/r/saiwaiyan09/bookinfo-reviews)

Each repository uses `original`, `updated`, and `optimized` tags for CI-managed images. The `manual-v1-original`, `manual-v1-updated`, and `manual-v1-optimized` tags preserve manually published benchmark versions separately from CI-managed tags.

Example:

```bash
docker pull saiwaiyan09/bookinfo-productpage:optimized
```

## Lessons learned

1. **Smaller is not automatic.** Updating a base image or adding stages can increase final image size, as seen with the Reviews experiment.
2. **Cache state matters.** BuildKit can reuse dependency installation, source-copy, and test layers; cached CI runs are not equivalent to clean local benchmarks.
3. **Measure the right size.** Image disk usage and the sum of compressed registry layers describe different things.
4. **Tags and digests serve different purposes.** CI-managed tags can be updated; image digests identify published image content, and separate `manual-v1-*` tags preserve benchmark references.
5. **Build pipelines are not deployment pipelines.** This project deliberately stops at building, publishing, and reporting image metadata.

## Technologies

Docker · Docker Buildx / BuildKit · GitHub Actions · Docker Hub · Linux · YAML · Bash · `jq` · Python · Ruby · Node.js · Java / Gradle

---

**Repository:** [saiwaiyan09/bookinfo-docker-cicd](https://github.com/saiwaiyan09/bookinfo-docker-cicd)  
**Focus:** Container image engineering, reproducible benchmarking, caching, and CI/CD automation.
