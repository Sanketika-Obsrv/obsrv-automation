# DHI-hardened variant of the obsrv kubectl utility image
#
# Debian -dev (1.32) -> Alpine -dev (1.35), measured with `trivy image`:
#   dhi.io/kubectl:1.32-debian13-dev + apt-get curl/jq/psql = 19 CRIT / 108 HIGH / 175 MED / 125 LOW (427 total)
#   dhi.io/kubectl:1.35-alpine3.22-dev + apk curl/jq/psql   =  0 CRIT /   2 HIGH /   0 MED /   0 LOW (2 total, after dropping kubectl-convert)
# Alpine's OS layer alone is drastically smaller/cleaner than Debian's here, and curl/jq/
# ca-certificates/postgresql-client all install fine via apk (postgresql17-client). 1.35 is
# used because dhi.io doesn't publish a 1.36-alpine variant yet (debian13 only, checked
# directly via `docker manifest inspect`).
FROM dhi.io/kubectl:1.35-alpine3.22-dev

USER root
# openssl: Debian's ca-certificates package pulls it in transitively (which is why the old
# Dockerfile "just worked" without an explicit install), but Alpine's ca-certificates does not
# -- confirmed missing on a real container run, breaking obsrv/generate-rsa-keys (does
# `openssl genpkey`/`openssl rsa` directly). Listed explicitly here instead.
RUN apk add --no-cache curl jq ca-certificates postgresql-client openssl \
 # kubectl-convert ships in the DHI image by default but is unused anywhere in this org
 # (confirmed: no references in any Dockerfile/script/chart) -- removing it halves the
 # remaining findings (it duplicates every kubectl binary CVE) for zero functional cost.
 && rm -f /usr/local/bin/kubectl-convert

# DHI non-root uid convention (jobs act via their ServiceAccount, not root)
USER 65532:65532
ENTRYPOINT []