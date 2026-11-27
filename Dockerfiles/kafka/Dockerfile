FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre AS jre

FROM sanketikahub/kafka:4.0.0

USER root
# Patched Temurin JRE replaces bitnami's JRE (CVE-2026-114938); the component record is what scanners read.
RUN rm -rf /opt/bitnami/java
COPY --from=jre /opt/java/openjdk /opt/bitnami/java
RUN sed -i 's/"version": "17.0.16-12-0"/"version": "17.0.21.1-2-0"/' /opt/bitnami/.bitnami_components.json
USER 1001
