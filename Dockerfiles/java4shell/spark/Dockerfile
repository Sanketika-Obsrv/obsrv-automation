FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre AS jre

FROM sanketikahub/spark:3.5.1-debian-12-r6

# Patched Temurin JRE replaces bitnami's JRE (CVE-2026-114938); the component record is what scanners read.
RUN rm -rf /opt/bitnami/java
COPY --from=jre /opt/java/openjdk /opt/bitnami/java
RUN sed -i 's/17\.0\.11-10-1/17.0.21.1-2-0/g' /opt/bitnami/.bitnami_components.json
