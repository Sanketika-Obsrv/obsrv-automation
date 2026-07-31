# DHI-hardened Secor (Pinterest Secor, built from https://github.com/Sanketika-Obsrv/secor).
ARG BASE_IMAGE=dhi.io/eclipse-temurin:11-jdk-debian13-dev

FROM ${BASE_IMAGE}

ENV SECOR_HOME=/opt/secor
WORKDIR ${SECOR_HOME}

USER 0
# DHI base has no useradd/groupadd — create the secor 9999 uid/gid directly
RUN printf 'secor:x:9999:9999:secor:/opt/secor:/bin/bash\n' >> /etc/passwd \
 && printf 'secor:x:9999:\n' >> /etc/group \
 && mkdir -p "$SECOR_HOME"

# secor distribution: maven-built tarball (target/secor-*-bin.tar.gz), same source as upstream
ADD --chown=9999:9999 target/secor-*-bin.tar.gz ${SECOR_HOME}/
COPY --chown=9999:9999 src/main/scripts/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh && chown -R 9999:9999 "$SECOR_HOME" /docker-entrypoint.sh

USER 9999:9999
ENTRYPOINT ["/docker-entrypoint.sh"]
