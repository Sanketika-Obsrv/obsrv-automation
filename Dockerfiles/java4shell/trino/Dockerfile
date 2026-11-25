FROM public.ecr.aws/docker/library/eclipse-temurin:25-jdk AS jdk

FROM trinodb/trino:476

USER root
# Java 24 is EOL with no fix; patched Temurin 25 JDK replaces it (CVE-2026-114938).
RUN rm -rf /usr/lib/jvm/temurin/jdk-24.0.1+9
COPY --from=jdk /opt/java/openjdk /usr/lib/jvm/temurin/jdk-25
ENV JAVA_HOME=/usr/lib/jvm/temurin/jdk-25 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/jvm/temurin/jdk-25/bin
USER trino:trino
