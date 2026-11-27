FROM public.ecr.aws/docker/library/eclipse-temurin:17-jre AS jre

FROM apache/druid:32.0.1

USER root
# Patched Temurin JRE replaces the base's Debian JDK (CVE-2026-114938).
COPY --from=jre /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk \
    JAVA_VERSION=17.0.21.1
RUN rm -rf /usr/lib/jvm /var/lib/dpkg/status.d/openjdk-17-jre-headless* \
    && ln -sf /opt/java/openjdk/bin/java /usr/bin/java \
    && chmod -R 755 /opt/druid/bin
USER druid
