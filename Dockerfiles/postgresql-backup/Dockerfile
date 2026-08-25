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
# The gcloud SDK tarball accounted for 13 of this image's 14 remaining findings, all inside two
# optional pieces of Google's own release artifact. Both are removable and both were verified
# working after removal (gsutil reaches the real GCS API and returns a 401 auth error, i.e. the
# full network/TLS/boto/auth path loads; `gcloud version` and `gsutil version -l` both run):
#
#  - platform/bundledpythonunix (~104MB): gcloud's OWN embedded Python 3.14, entirely separate
#    from the 3.12 this image runs. 5 findings (cryptography 46.0.7 + setuptools 80.10.2 inside
#    it). gcloud officially supports an external interpreter via CLOUDSDK_PYTHON, set below --
#    gsutil then reports "python version: 3.12.14", our own already-patched interpreter.
#  - bin/gcloud-crc32c: an optional Go-compiled checksum accelerator, 8 findings (Go stdlib CVEs
#    that only Google can fix by rebuilding). gsutil falls back to its own crc32c implementation;
#    note `compiled crcmod: False` was already the case before this removal, so integrity
#    checking behaviour is unchanged -- this binary was not being used as the fast path anyway.
RUN rm -rf /google-cloud-sdk/platform/bundledpythonunix \
 && rm -f /google-cloud-sdk/bin/gcloud-crc32c

# ---------- runtime ----------
# Still the -dev tag, not the plain distroless one: postgres-backup.sh runs as the container's
# ENTRYPOINT (not just a build step) and needs a real shell (`#!/bin/bash`) plus apk-installed
# CLI tools (psql, aws, bzip2) at every cron run -- confirmed the plain (non-dev) DHI python tag
# ships no /bin/sh at all, so it cannot run this script. What IS dropped vs. the old single-stage
# build: the whole compiler toolchain above, which the runtime never needs.
FROM dhi.io/python:3.12-alpine3.22-dev
USER 0
# Point gcloud/gsutil at the DHI base's own (patched) python instead of the bundled 3.14 runtime
# removed in the build stage above. Uses the /opt/python symlink DHI ships rather than the
# versioned /opt/python-3.12.14 path: the latter disappears the moment DHI bumps the patch
# release, and this is a RUNTIME lookup -- it would fail inside the nightly cron job rather than
# loudly at build time.
ENV CLOUDSDK_PYTHON=/opt/python/bin/python3
# libffi/openssl (runtime shared libs, not the -dev header packages) are needed by the compiled
# cryptography/etc. extensions inside azure-cli's copied site-packages.
RUN apk --no-cache add postgresql17-client aws-cli bash bzip2 libffi openssl
# Copy the build stage's whole python install (base + azure-cli, including the az/azd console
# scripts pip generated under its bin/) over the runtime's identical base copy.
# This one path stays version-pinned deliberately: COPY can't glob a directory without flattening
# it, and /opt holds a `docker` dir too so a blanket `COPY /opt /opt` would drag that in. A DHI
# patch bump makes this fail loudly at BUILD time ("not found"), which is the safe direction --
# unlike the runtime lookups above, which were switched to the /opt/python symlink.
COPY --from=build /opt/python-3.12.14 /opt/python-3.12.14
COPY --from=build /google-cloud-sdk /google-cloud-sdk
COPY ./postgres-backup.sh /
# pip itself (used only to install azure-cli above) ships a vendored msgpack, and ensurepip
# carries a bundled setuptools wheel -- both flagged by trivy, neither used at runtime:
# postgres-backup.sh never invokes pip/ensurepip, only psql/bzip2/aws/gsutil/az. Safe to strip.
# Paths derived from sysconfig / the /opt/python symlink rather than hardcoded 3.12.14, so a DHI
# patch bump doesn't silently turn these into no-ops that leave pip in the shipped image.
RUN PYLIB=$(python3 -c "import sysconfig; print(sysconfig.get_paths()['purelib'])") \
 && rm -rf "$PYLIB"/pip "$PYLIB"/pip-*.dist-info \
           /opt/python/bin/pip /opt/python/bin/pip3 /opt/python/bin/pip3.* \
           "$(python3 -c 'import sysconfig; print(sysconfig.get_paths()["stdlib"])')/ensurepip/_bundled"
RUN mkdir -p /var/postgres/backups \
 && chown -R 65532:65532 /var/postgres/backups /google-cloud-sdk
# No PVC/volume is mounted by the postgresql-backup CronJob (confirmed against the live cluster
# spec) -- backups are streamed straight to s3/gcs/azure, so there's no host-path permission
# reason to stay root. DHI's standard nonroot uid.
USER 65532
ENTRYPOINT ["sh", "/postgres-backup.sh"]
