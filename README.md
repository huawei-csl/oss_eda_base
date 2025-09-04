# oss-eda-base

Shared Docker base image providing common EDA toolchain and Python env for GENIAL, Flowy, and related projects. It now bakes `oss_eda_flow_scripts` into the image so overlays don’t need to vendor it.

## Submodule Setup

This repo embeds the flow scripts as a Git submodule at `ext/oss_eda_flow_scripts`.

- Add (first-time): `git submodule add https://github.com/<org>/oss_eda_flow_scripts.git ext/oss_eda_flow_scripts`
- Initialize/update: `git submodule update --init --recursive`

When building from another repository that vendors this repo (e.g., monorepo using `-f ext/oss_eda_base/Dockerfile`), ensure you run the init command at the other repository’s root so the submodule is populated in the build context.

## Build locally

From the repository root (BuildKit required):

- Monorepo (build from monorepo root):
  `DOCKER_BUILDKIT=1 docker build -f ext/oss_eda_base/Dockerfile --build-arg NPROC=$(nproc) --build-arg OEDA_SCRIPTS_REV=$(git -C ext/oss_eda_base/ext/oss_eda_flow_scripts rev-parse HEAD || date +%s) -t oss-eda-base:latest .`

- Standalone `oss_eda_base` repo:
  `DOCKER_BUILDKIT=1 docker build -f Dockerfile --build-arg NPROC=$(nproc) --build-arg OEDA_SCRIPTS_REV=$(git -C ext/oss_eda_flow_scripts rev-parse HEAD || date +%s) -t oss-eda-base:latest .`

The `OEDA_SCRIPTS_REV` build-arg ties the cache to the submodule revision so the step that imports `oss_eda_flow_scripts` re-runs when the scripts change.

The Dockerfile automatically looks for the submodule at `ext/oss_eda_base/ext/oss_eda_flow_scripts` (when building from a monorepo root) or `ext/oss_eda_flow_scripts` (when building this repo directly). If not found, the build fails with a clear error explaining how to initialize submodules.

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

## Troubleshooting

- Build error about missing `oss_eda_flow_scripts`:
  Ensure submodules are initialized: `git submodule update --init --recursive`
  If building from another repo, run the command at that repo’s root.
