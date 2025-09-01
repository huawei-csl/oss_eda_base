# oss-eda-base

Shared Docker base image providing common EDA toolchain and Python env for DGFE, Flowy, and related projects.

## Build locally

From the repository root:

```
docker build \
  -f ext/oss_eda_base/Dockerfile \
  --build-arg NPROC=$(nproc) \
  -t oss-eda-base:latest \
  .
```

Optionally preinstall project requirements by ensuring `requirements.txt` exists in the build context root.

## Use as a base

In project-specific Dockerfiles:

```
FROM oss-eda-base:latest
# add your project-specific steps here
```

## Publishing

After creating a remote repository (e.g., GitHub), you can push this folder as its own repo (see instructions in the main PR/commit message).

