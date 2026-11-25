FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre AS jre

FROM flyway/flyway:10.12.0

# Patched Temurin JRE replaces the bundled JDK (CVE-2026-114938).
RUN rm -rf /opt/java/openjdk
COPY --from=jre /opt/java/openjdk /opt/java/openjdk
ENV JAVA_VERSION=jre-17.0.21.1+2
