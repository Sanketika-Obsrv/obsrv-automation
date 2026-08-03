# DHI-hardened variant of the obsrv kubectl utility image
FROM dhi.io/kubectl:1.32-debian13-dev

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl jq ca-certificates postgresql-client \
 && rm -rf /var/lib/apt/lists/*

# DHI non-root uid convention (jobs act via their ServiceAccount, not root)
USER 65532:65532
ENTRYPOINT []