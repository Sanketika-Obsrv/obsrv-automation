FROM public.ecr.aws/docker/library/eclipse-temurin:21-jre AS jre

FROM sanketikahub/keycloak-config-cli:6.2.0-debian-12-r0

USER root
# Patched Temurin JRE replaces bitnami's JRE (CVE-2026-114938); the component record is what scanners read.
RUN rm -rf /opt/bitnami/java
COPY --from=jre /opt/java/openjdk /opt/bitnami/java
RUN sed -i 's/21\.0\.5-11-1/21.0.13.1-2-0/g' /opt/bitnami/.bitnami_components.json
USER 1001
