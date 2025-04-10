{{/*

 Licensed to the Apache Software Foundation (ASF) under one or more
 contributor license agreements.  See the NOTICE file distributed with
 this work for additional information regarding copyright ownership.
 The ASF licenses this file to You under the Apache License, Version 2.0
 (the "License"); you may not use this file except in compliance with
 the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

*/}}
{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "superset.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "superset.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "superset.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "superset-config" }}
import os
import logging
import ast
from cachelib.redis import RedisCache
from flask import has_request_context, session, g
from flask_login import current_user
import urllib3
import redis

def env(key, default=None):
    return os.getenv(key, default)

MAPBOX_API_KEY = env('MAPBOX_API_KEY', '')
CACHE_CONFIG = {
    'CACHE_TYPE': 'redis',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': env('REDIS_HOST'),
    'CACHE_REDIS_PORT': env('REDIS_PORT'),
    'CACHE_REDIS_PASSWORD': env('REDIS_PASSWORD'),
    'CACHE_REDIS_DB': env('REDIS_DB', 1),
}
DATA_CACHE_CONFIG = CACHE_CONFIG

SQLALCHEMY_DATABASE_URI = f"postgresql+psycopg2://{env('DB_USER')}:{env('DB_PASS')}@{env('DB_HOST')}:{env('DB_PORT')}/{env('DB_NAME')}"
SQLALCHEMY_TRACK_MODIFICATIONS = True
SECRET_KEY = env('SECRET_KEY', 'thisISaSECRET_1234')

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = False
# Add endpoints that need to be exempt from CSRF protection
WTF_CSRF_EXEMPT_LIST = []
# A CSRF token that expires in 1 year
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 365
class CeleryConfig(object):
    BROKER_URL = f"redis://{env('REDIS_HOST')}:{env('REDIS_PORT')}/0"
    CELERY_IMPORTS = ('superset.sql_lab', )
    CELERY_RESULT_BACKEND = f"redis://{env('REDIS_HOST')}:{env('REDIS_PORT')}/0"
    CELERY_ANNOTATIONS = {'tasks.add': {'rate_limit': '10/s'}}

CELERY_CONFIG = CeleryConfig
RESULTS_BACKEND = RedisCache(
    host=env('REDIS_HOST'),
    port=env('REDIS_PORT'),
    key_prefix='superset_results'
)

sso_cache = redis.Redis(
    host=env("REDIS_HOST"),
    port=int(env("REDIS_PORT")),
    password=env("REDIS_PASSWORD"),
    db=int(env("REDIS_DB", 1)),
    decode_responses=True,
)

def get_token_for_user(user_id):
    return sso_cache.get(f"sso_user_token:{user_id}")

def get_access_token_from_session():
    """Extract access token from session based on the observed format"""
    try:
        if 'oauth' in session:
            oauth_value = session['oauth']

            # Check if it's already a tuple
            if isinstance(oauth_value, tuple) and len(oauth_value) >= 1:
                return oauth_value[0]

            # If it's a string representation of a tuple
            elif isinstance(oauth_value, str):
                # Try basic string parsing first (safer than eval)
                if oauth_value.startswith("('") and "'," in oauth_value:
                    token = oauth_value.split("',")[0].strip("('")
                    return token

                # Fallback to ast.literal_eval if needed
                try:
                    parsed = ast.literal_eval(oauth_value)
                    if isinstance(parsed, tuple) and parsed:
                        return parsed[0]
                except (SyntaxError, ValueError):
                    pass

            logging.info(f"OAuth value format: {type(oauth_value)}")
    except Exception as e:
        logging.error(f"Error extracting token from session: {e}")

    return None

_original_urlopen = urllib3.connectionpool.HTTPConnectionPool.urlopen
def patched_urlopen(self, method, url, body=None, headers=None, *args, **kwargs):
    if "dataset-api.{{.Values.global.namespaces.dataset_api_namespace}}" in str({self.host}):
        logging.info("🔄 Dataset API request detected, injecting token")
        token = None
        if headers is None:
            headers = {}

        # Check if we have a token in the session
        if has_request_context():
            token = get_access_token_from_session()

        if not token:
            logging.info("🔄 No token in session, trying to get from Cache")
            global_user = g.user.username if hasattr(g, 'user') and hasattr(g.user, 'username') and g.user is not None else None
            token = get_token_for_user(global_user)

        if token:
            headers["Authorization"] = f"Bearer {token}"
            logging.info(f"✅ Injected bearer token for user request {token[0:5]}...{token[-5:]}")
        else:
            logging.warning("⚠️ No access token found")

    return _original_urlopen(self, method, url, body=body, headers=headers, *args, **kwargs)

urllib3.connectionpool.HTTPConnectionPool.urlopen = patched_urlopen
logging.info("✅ Patched urllib3 to inject bearer token")

{{ if .Values.configOverrides }}
{{- $oauth_enabled := .Values.oauth_enabled -}}
# Overrides
{{- range $key, $value := .Values.configOverrides }}
{{- if or (ne $key "oauth") (default $oauth_enabled false) }}
# {{ $key }}
{{ tpl $value $ }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}
