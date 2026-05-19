FROM apache/superset:6.1.0
USER root
RUN uv pip install --python /app/.venv/bin/python Authlib psycopg2-binary pydruid sqlalchemy-trino
USER superset