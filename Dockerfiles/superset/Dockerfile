# DHI hardened build. Extra DB/auth drivers are installed into superset's venv using the
# -dev variant (has pip + toolchain), then the augmented venv is copied into the minimal
# hardened runtime (nonroot uid 65532, venv at /app/.venv, entrypoint run-server.sh).
ARG BUILD_IMAGE=dhi.io/superset:6-debian13-dev
ARG RUNTIME_IMAGE=dhi.io/superset:6-debian13

FROM ${BUILD_IMAGE} AS build
# USER 0, not `root`: this image has no root entry in /etc/passwd, only the numeric uid.
USER 0

# flask: the base ships 2.3.3, the oldest Superset allows (it pins flask<4.0.0,>=2.2.5).
RUN /app/.venv/bin/pip install --no-cache-dir Authlib psycopg2-binary pydruid trino \
    && /app/.venv/bin/pip install --no-cache-dir "flask==3.1.3" \
    && chmod -R a+rX /app/.venv

FROM ${RUNTIME_IMAGE}
USER 0
# Same venv path in both variants; copy the driver-augmented venv into the hardened runtime.
COPY --from=build --chown=65532:65532 /app/.venv /app/.venv
# Drop pip/ensurepip -- never invoked at runtime. Must run after the COPY, which reintroduces the
# build stage's copy. Deleted via python because this runtime has no coreutils (no `rm` on PATH).
RUN /app/.venv/bin/python -c "\
import shutil, os; \
[shutil.rmtree(p, ignore_errors=True) if os.path.isdir(p) else os.path.exists(p) and os.remove(p) \
 for p in ['/usr/bin/pip', '/usr/lib/python3/dist-packages/pip', '/usr/lib/python3.11/ensurepip', \
           '/app/.venv/bin/pip', '/app/.venv/lib/python3.11/site-packages/pip']]"
USER 65532
