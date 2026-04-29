# syntax=docker/dockerfile:1.4
# OSS EDA Base image
# Shared base for DGFE and Flowy (and other projects)

FROM ubuntu:24.04 AS base
SHELL ["/bin/bash", "-lc"]

# Base environment
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_ROOT_USER_ACTION=ignore

# System dependencies (no recommends)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git unzip zip \
    build-essential g++ make cmake \
    autoconf automake libtool pkg-config \
    flex bison help2man \
    numactl libgoogle-perftools-dev \
    libfl2 libfl-dev \
    zlib1g-dev libreadline-dev libffi-dev \
    graphviz xdot tcl-dev gawk \
    libboost-system-dev libboost-filesystem-dev libboost-python-dev \
    swig perl python3 python3-dev python3.12-dev python3-venv sudo \
    locales \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/morty /opt/sv2v /proj /prog

# Build parallelism
ARG NPROC=8

#########################################################
# Python (via uv) and basic packages
#########################################################
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
 && install -m 0755 /root/.local/bin/uv /usr/local/bin/uv

ENV PATH=/usr/local/bin:$PATH

# Ensure uv installs Python and cache in predictable locations
ENV UV_PYTHON_INSTALL_DIR=/home/vscode/.uv/python \
    XDG_CACHE_HOME=/home/vscode/.cache

RUN mkdir -p /home/vscode/.uv/python /home/vscode/.cache \
 && chmod 0755 -R /home/vscode/.uv /home/vscode/.cache

# Developer user
RUN useradd -m -s /bin/bash vscode \
 && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
 && chmod 0440 /etc/sudoers.d/vscode \
 && chown -R vscode:vscode /prog

# Create venv in the location expected by downstream images
RUN uv venv /home/vscode/pyenv_eda --python=3.13 \
 && chown -R vscode:vscode /home/vscode/pyenv_eda

# Make it available system-wide
RUN ln -sf /home/vscode/pyenv_eda/bin/python /usr/local/bin/python \
 && ln -sf /home/vscode/pyenv_eda/bin/python3 /usr/local/bin/python3

# Ensure it is used by default
ENV PATH=/home/vscode/pyenv_eda/bin:$PATH

# Optional: persist for login shells
RUN echo 'export PATH="/home/vscode/pyenv_eda/bin:$PATH"' > /etc/profile.d/pyenv_eda.sh
# Core Python libs commonly used across projects
RUN uv pip install cocotb==1.9.2 numpy pandas pyarrow pyyaml pytest tqdm matplotlib

## Optional requirements preinstall removed to avoid copying full context

#########################################################
# ASAP7 library 
# Done early to simplify dockerfile modifications
#########################################################
# RUN git clone https://github.com/The-OpenROAD-Project/asap7sc7p5t_28.git /app/asap7sc7p5t_28
# ENV MODEL_SOURCES=/app/asap7sc7p5t_28/Verilog

#########################################################
# Verilator
#########################################################
ARG VERILATOR_VER="tags/v5.036"
RUN git clone https://github.com/verilator/verilator /proj/verilator \ 
 && cd /proj/verilator \
 && git checkout -b build_version ${VERILATOR_VER} \
 && autoconf \
 && ./configure \
 && make -j ${NPROC} \
 && make install
ENV PATH=$PATH:/prog/verilator/bin

#########################################################
# Yosys
#########################################################
ARG YOSYS_VER="tags/v0.55"
RUN git clone https://github.com/YosysHQ/yosys.git /proj/yosys \
 && cd /proj/yosys \
 && git checkout -b build_version ${YOSYS_VER} \
 && git submodule update --init \
 && make config-gcc \
 && make -j ${NPROC} \
 && make install
RUN git clone --recursive https://github.com/povik/yosys-slang /proj/yosys/yosys-slang \
 && cd /proj/yosys/yosys-slang \
 && make -j ${NPROC} \
 && make install
ENV PATH=$PATH:/proj/yosys/bin

#########################################################
# PULP Tool Suite (Bender, Morty, Svase) and SV2V
#########################################################
WORKDIR /usr/bin
RUN curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | bash

RUN curl -fsSLo /tmp/morty.tar.gz https://github.com/pulp-platform/morty/releases/download/v0.9.0/morty-ubuntu.22.04-x86_64.tar.gz \
 && tar -C /tmp -xf /tmp/morty.tar.gz \
 && install -m 0755 /tmp/morty /usr/bin/morty \
 && rm -rf /tmp/morty*

RUN git clone https://github.com/pulp-platform/svase.git /opt/svase \
 && cd /opt/svase \
 && git checkout -b build_version e192e39 \
 && sed -i 's/ -Werror//g' CMakeLists.txt \
 && make build \
 && install -m 0755 /opt/svase/build/svase /usr/bin/svase

RUN mkdir -p /opt/sv2v \
 && cd /opt/sv2v \
 && wget -q https://github.com/zachjs/sv2v/releases/download/v0.0.12/sv2v-Linux.zip \
 && unzip -q sv2v-Linux.zip \
 && install -m 0755 sv2v-Linux/sv2v /usr/bin/sv2v \
 && rm -rf sv2v-Linux*

#########################################################
# OpenSTA and deps (CUDD + Eigen)
#########################################################
RUN git clone https://github.com/davidkebo/cudd /prog/cudd \
 && cd /prog/cudd/cudd_versions \
 && tar xfz cudd-3.0.0.tar.gz \
 && cd /prog/cudd/cudd_versions/cudd-3.0.0 \
 && ./configure --prefix=/prog/cudd/cudd_versions/cudd-3.0.0 \
 && make -j ${NPROC} install
ENV CUDD_INSTALL_DIR=/prog/cudd/cudd_versions/cudd-3.0.0

# RA: old version
#RUN git clone https://gitlab.com/libeigen/eigen.git /prog/eigen \
# && cmake -S /prog/eigen -B /prog/eigen/build_dir \
# && cmake --install /prog/eigen/build_dir

# RA: new version
RUN git clone https://gitlab.com/libeigen/eigen.git /prog/eigen \
 && cd /prog/eigen \
 && git checkout 3.4.0 \
 && cmake -S /prog/eigen -B /prog/eigen/build_dir -DEIGEN_TEST_NOQT=ON -DEIGEN_BUILD_TESTS=OFF -DEIGEN_BUILD_DOC=OFF \
 && cmake --install /prog/eigen/build_dir

RUN git clone https://github.com/parallaxsw/OpenSTA.git /prog/OpenSTA \
 && cmake -S /prog/OpenSTA -B /prog/OpenSTA/build -DCUDD_DIR=${CUDD_INSTALL_DIR} \
 && cmake --build /prog/OpenSTA/build -j ${NPROC}
ENV PATH=$PATH:/prog/OpenSTA/app

#########################################################
# OpenROAD Flow Scripts 
#########################################################
# RUN git clone https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts /prog/OpenROAD-flow-scripts
# WORKDIR /prog/OpenROAD-flow-scripts
# RUN sed -i 's/sudo -u $SUDO_USER//g' setup.sh \
#   && ./setup.sh \
#   && PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
#     PYTHONNOUSERSITE=1 \
#     Python3_EXECUTABLE=/usr/bin/python3 \
#     ./build_openroad.sh --local
# ENV PATH=$PATH:/prog/OpenROAD-flow-scripts/tools/install/OpenROAD/bin/

#########################################################
# Trace 2 Power
#########################################################
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
# ENV PATH="/root/.cargo/bin:${PATH}"
# RUN git clone https://github.com/antmicro/trace2power.git /prog/trace2power
# WORKDIR /prog/trace2power
# RUN git checkout 74949-glitch-power && cargo install --path .


#########################################################
# Polishing
#########################################################

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
WORKDIR /app

#########################################################
# Bring in OSS EDA flow scripts from the submodule location
# This supports two build contexts:
# 1) Building this repo directly:             ext/oss_eda_flow_scripts
# 2) Building from a monorepo root using -f:  ext/oss_eda_base/ext/oss_eda_flow_scripts
# If the submodule is missing, fail with a clear message.
#########################################################
ARG OEDA_SCRIPTS_REV=dev
RUN --mount=type=bind,source=.,target=/context <<EOS
set -euo pipefail
# tie cache key to scripts revision provided by build-arg
echo "bust=${OEDA_SCRIPTS_REV}" >/dev/null
src=""
if [[ -d /context/ext/oss_eda_base/ext/oss_eda_flow_scripts ]]; then
  src=/context/ext/oss_eda_base/ext/oss_eda_flow_scripts
elif [[ -d /context/ext/oss_eda_flow_scripts ]]; then
  src=/context/ext/oss_eda_flow_scripts
else
  echo "\nERROR: oss_eda_flow_scripts submodule not found in build context.\n" >&2
  echo "Expected at one of:" >&2
  echo "  - ext/oss_eda_base/ext/oss_eda_flow_scripts (when building from a monorepo root)" >&2
  echo "  - ext/oss_eda_flow_scripts (when building this repo directly)" >&2
  echo "\nFix: Ensure git submodules are initialized recursively before building:" >&2
  echo "  git submodule update --init --recursive" >&2
  echo "\nIf building from another repository, run the command at that repo root." >&2
  exit 1
fi
mkdir -p /app/oss_eda_flow_scripts
cp -a "$src"/. /app/oss_eda_flow_scripts/
EOS


# Ensure vscode user has a writable cache for uv and friends
RUN mkdir -p /home/vscode/.cache/uv /tmp/mplconfig \
 && chown -R vscode:vscode /home/vscode /tmp/mplconfig

# Provide a stable `python` in PATH even if only `python3` exists
RUN ln -sf /prog/pyenv_eda/bin/python /usr/local/bin/python


LABEL org.opencontainers.image.title="oss-eda-base" \
      org.opencontainers.image.description="Shared EDA base for DGFE and Flowy" \
      org.opencontainers.image.source="https://github.com/MaxenceBouvier/oss-eda-base"

