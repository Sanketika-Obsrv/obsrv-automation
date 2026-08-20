# ---------- build (compiler toolchain + pip/gcloud install, torn down after) ----------
FROM dhi.io/python:3.12-alpine3.22-dev AS build
USER 0
ARG TARGETARCH
# gcc/musl-dev/python3-dev/libffi-dev/openssl-dev/cargo/make are ONLY needed to compile azure-cli's
# native deps (cryptography etc.); curl only to fetch the gcloud tarball. None of this belongs in
# the runtime image -- confirmed by testing the final image below without them.
RUN apk --no-cache add curl gcc musl-dev python3-dev libffi-dev openssl-dev cargo make py3-pip
RUN pip install --upgrade pip --root-user-action=ignore
# Installed straight into the base's own site-packages (not --prefix=/install): this image's
# python does not search /usr/local for packages (confirmed -- sys.path has no /usr/local entry,
# and az's own shebang is /opt/python-3.12.14/bin/python3.12), so a --prefix install is invisible
# to it. Safe to copy the whole tree below since build and runtime share the identical base image.
RUN pip install --root-user-action=ignore azure-cli
# azure-cli itself pins no upper bound on cryptography, but pip's resolver still landed on an
# older release satisfying some other transitive constraint. Force the newest compatible one --
# confirmed this resolves cleanly to a prebuilt musllinux wheel (no compiler needed) and azure-cli
# still imports correctly below.
RUN pip install --root-user-action=ignore --upgrade cryptography
# gcloud SDK tarball is arch-specific: x86_64 on amd64, arm on arm64. Pick per TARGETARCH so the
# image is multi-arch (was hardcoded x86_64, which shipped an amd64 gcloud into arm64 images).
RUN case "${TARGETARCH}" in \
      amd64) GARCH=x86_64 ;; \
      arm64) GARCH=arm ;; \
      *)     GARCH=x86_64 ;; \
    esac \
 && curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${GARCH}.tar.gz" \
 && tar -xf "google-cloud-cli-linux-${GARCH}.tar.gz" -C / \
 && /google-cloud-sdk/install.sh --quiet \
 && rm "google-cloud-cli-linux-${GARCH}.tar.gz"
RUN /google-cloud-sdk/bin/gcloud config set disable_usage_reporting true

# ---------- runtime ----------
# Still the -dev tag, not the plain distroless one: postgres-backup.sh runs as the container's
# ENTRYPOINT (not just a build step) and needs a real shell (`#!/bin/bash`) plus apk-installed
# CLI tools (psql, aws, bzip2) at every cron run -- confirmed the plain (non-dev) DHI python tag
# ships no /bin/sh at all, so it cannot run this script. What IS dropped vs. the old single-stage
# build: the whole compiler toolchain above, which the runtime never needs.
FROM dhi.io/python:3.12-alpine3.22-dev
USER 0
# libffi/openssl (runtime shared libs, not the -dev header packages) are needed by the compiled
# cryptography/etc. extensions inside azure-cli's copied site-packages.
RUN apk --no-cache add postgresql17-client aws-cli bash bzip2 libffi openssl
# Copy the build stage's whole python install (base + azure-cli, including the az/azd console
# scripts pip generated under its bin/) over the runtime's identical base copy.
COPY --from=build /opt/python-3.12.14 /opt/python-3.12.14
COPY --from=build /google-cloud-sdk /google-cloud-sdk
COPY ./postgres-backup.sh /
# pip itself (used only to install azure-cli above) ships a vendored msgpack, and ensurepip
# carries a bundled setuptools wheel -- both flagged by trivy, neither used at runtime:
# postgres-backup.sh never invokes pip/ensurepip, only psql/bzip2/aws/gsutil/az. Safe to strip.
RUN PYLIB=$(python3 -c "import sysconfig; print(sysconfig.get_paths()['purelib'])") \
 && rm -rf "$PYLIB"/pip "$PYLIB"/pip-*.dist-info \
           /opt/python-3.12.14/bin/pip /opt/python-3.12.14/bin/pip3 /opt/python-3.12.14/bin/pip3.* \
           "$(python3 -c 'import sysconfig; print(sysconfig.get_paths()["stdlib"])')/ensurepip/_bundled"
RUN mkdir -p /var/postgres/backups \
 && chown -R 65532:65532 /var/postgres/backups /google-cloud-sdk
# No PVC/volume is mounted by the postgresql-backup CronJob (confirmed against the live cluster
# spec) -- backups are streamed straight to s3/gcs/azure, so there's no host-path permission
# reason to stay root. DHI's standard nonroot uid.
USER 65532
ENTRYPOINT ["sh", "/postgres-backup.sh"]
