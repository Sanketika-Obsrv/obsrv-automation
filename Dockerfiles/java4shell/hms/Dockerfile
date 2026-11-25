FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre AS jre

FROM sanketikahub/hms:1.0.5

# Patched Temurin JRE replaces the bundled one (CVE-2026-114938).
RUN rm -rf /opt/java/openjdk
COPY --from=jre /opt/java/openjdk /opt/java/openjdk
ENV JAVA_VERSION=jre-17.0.21.1+2
