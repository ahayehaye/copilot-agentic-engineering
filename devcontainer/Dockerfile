# Phase 4 — daily-driver toolchain (ASE #482).
# Base image matches the host shape (Debian 13 / trixie).
FROM debian:trixie

# The container user matches the WSL host uid so files created in bind
# mounts are owned by the right user on the host side. Per-machine
# override: devcontainer.user.local.json -> build.args (see README).
ARG DEV_UID=1000
ARG DEV_GID=1000

# Locale: the locales package ships no generated locales; without this
# every shell warns "cannot change locale (en_US.UTF-8)".
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ── Base toolchain (Tier 1) ────────────────────────────────────────────────
# Package list grounded in the fizban dev-box scan (same base) + two weeks
# of observed session / bash-history usage (ASE #482). `apt-file` is the
# escape hatch for "which package provides X". `sudo` + the sudoers drop-in
# enable the runtime-install workflow: `sudo apt-get update && sudo apt-get
# install pkg` mid-session, no rebuild — the drift check in preflight.sh
# names what to commit back here.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git gh jq \
    openssh-client \
    python3 python3-venv python3-pip python3-dev \
    build-essential \
    ripgrep fd-find \
    vim less man-db manpages \
    procps lsof psmisc strace \
    tree htop file netcat-openbsd \
    tar gzip bzip2 xz-utils zstd zip unzip \
    patch diffutils dos2unix \
    iproute2 iputils-ping \
    openssl \
    locales bash-completion apt-file \
    sudo \
    && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && groupadd -g ${DEV_GID} dev \
    && useradd -m -u ${DEV_UID} -g ${DEV_GID} -s /bin/bash dev \
    && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# GitHub Copilot CLI — official install script (installs to /usr/local/bin).
# "Latest" is INTENTIONAL: the WSL2 device-code polling fix (copilot-cli
# #1112) only exists in newer releases, so pinning would re-break login.
# preflight records the installed version.
RUN curl -fsSL https://gh.io/copilot-install | bash

# ── Package baseline (drift detection) ─────────────────────────────────────
# Build-time snapshot of the installed package list. Runtime
# `sudo apt-get install` packages show up as drift: preflight.sh container
# diffs live vs this baseline and names the uncommitted packages.
RUN dpkg-query -W > /var/lib/pkg-baseline

# Auth is NOT baked in: tokens live in bind-mounted ~/.copilot, ~/.ssh, and
# ~/.config/gh (see devcontainer.json mounts), so sign-ins survive rebuilds.
USER dev
WORKDIR /workspaces/vscode
