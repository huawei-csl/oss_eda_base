# oss-eda-base

Shared Docker base image providing common EDA toolchain and Python env for DGFE, Flowy, and related projects. It now bakes `oss_eda_flow_scripts` into the image so overlays don’t need to vendor it.

## Build locally

From the repository root:

Monorepo (this repo contains `ext/oss_eda_flow_scripts/`):

```
docker build \
  -f ext/oss_eda_base/Dockerfile \
  --build-arg NPROC=$(nproc) \
  --build-arg OEDA_PATH=ext/oss_eda_flow_scripts \
  -t oss-eda-base:latest \
  .
```

Standalone `oss_eda_base` repo (with `oss_eda_flow_scripts/` as submodule at repo root):

```
docker build \
  -f Dockerfile \
  --build-arg NPROC=$(nproc) \
  --build-arg OEDA_PATH=oss_eda_flow_scripts \
  -t oss-eda-base:latest \
  .
```

## Use as a base

In project-specific Dockerfiles:

```
ARG BASE_IMAGE=oss-eda-base:latest
FROM ${BASE_IMAGE}
# add your project-specific steps here
```

## Publishing

After creating a remote repository (e.g., GitHub), you can push this folder as its own repo. If you publish to GHCR, overlays can use:

```
docker build \
  --build-arg BASE_IMAGE=ghcr.io/<org>/oss-eda-base:latest \
  -f <overlay-Dockerfile> \
  -t <overlay-tag> \
  .
```
