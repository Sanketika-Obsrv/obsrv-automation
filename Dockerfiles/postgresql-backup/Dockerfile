FROM dhi.io/python:3.12-alpine3.22-dev
USER 0
ARG TARGETARCH
COPY ./postgres-backup.sh /
RUN apk --no-cache add postgresql17-client aws-cli
RUN apk add --no-cache curl py3-pip
RUN apk add --no-cache gcc musl-dev python3-dev libffi-dev openssl-dev cargo make
RUN pip install --upgrade pip
RUN pip install azure-cli
# gcloud SDK tarball is arch-specific: x86_64 on amd64, arm on arm64. Pick per TARGETARCH so the
# image is multi-arch (was hardcoded x86_64, which shipped an amd64 gcloud into arm64 images).
RUN case "${TARGETARCH}" in \
      amd64) GARCH=x86_64 ;; \
      arm64) GARCH=arm ;; \
      *)     GARCH=x86_64 ;; \
    esac \
 && curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${GARCH}.tar.gz" \
 && tar -xf "google-cloud-cli-linux-${GARCH}.tar.gz" \
 && /google-cloud-sdk/install.sh --quiet \
 && rm "google-cloud-cli-linux-${GARCH}.tar.gz"
RUN /google-cloud-sdk/bin/gcloud config set disable_usage_reporting true
RUN apk del curl py3-pip cargo make
ENTRYPOINT ["sh", "/postgres-backup.sh"]