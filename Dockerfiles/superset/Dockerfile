# DHI hardened build. Extra DB/auth drivers are installed into superset's venv using the
# -dev variant (has pip + toolchain), then the augmented venv is copied into the minimal
# hardened runtime (nonroot uid 65532, venv at /app/.venv, entrypoint run-server.sh).
ARG BUILD_IMAGE=dhi.io/superset:6-debian13-dev
ARG RUNTIME_IMAGE=dhi.io/superset:6-debian13

FROM ${BUILD_IMAGE} AS build
USER root

RUN /app/.venv/bin/pip install --no-cache-dir Authlib psycopg2-binary pydruid trino \
    && chmod -R a+rX /app/.venv

FROM ${RUNTIME_IMAGE}
# Same venv path in both variants; copy the driver-augmented venv into the hardened runtime.
COPY --from=build --chown=65532:65532 /app/.venv /app/.venv