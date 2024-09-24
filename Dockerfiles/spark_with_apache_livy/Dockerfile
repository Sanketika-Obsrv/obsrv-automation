FROM --platform=linux/amd64 docker.io/bitnami/spark:3.5.1-debian-12-r6
USER root
ARG CONF_PATH=.
ENV LIVY_HOME=/opt/bitnami/livy

# Install necessary packages
RUN install_packages unzip curl git

# install apache livy server
RUN curl "https://archive.apache.org/dist/incubator/livy/0.8.0-incubating/apache-livy-0.8.0-incubating_2.12-bin.zip" -o "apache-livy-0.8.0-incubating_2.12-bin.zip" \
    && unzip "apache-livy-0.8.0-incubating_2.12-bin.zip" \
    && rm -rf "apache-livy-0.8.0-incubating_2.12-bin.zip" \
    && mv "apache-livy-0.8.0-incubating_2.12-bin" $LIVY_HOME \
    && mkdir $LIVY_HOME/logs \
    && mkdir /tmp/spark-events \
    && chown -R 1001:1001 $LIVY_HOME

RUN cd /tmp && curl -LO https://repo1.maven.org/maven2/org/postgresql/postgresql/42.3.1/postgresql-42.3.1.jar && mv postgresql-42.3.1.jar /opt/bitnami/spark/jars/

#Replacing the existing 14.0.1 guava version with 19.0 for WFS Support
RUN cd /tmp && curl -LO https://repo1.maven.org/maven2/com/google/guava/guava/19.0/guava-19.0.jar && mv guava-19.0.jar /opt/bitnami/spark/jars/
RUN mv /opt/bitnami/spark/jars/guava-14.0.1.jar /tmp

COPY ${CONF_PATH}/conf/ /opt/bitnami/livy/conf/
COPY ${CONF_PATH}/log4j.properties /opt/bitnami/spark/conf/
COPY ${CONF_PATH}/custom-init.sh /opt/bitnami/spark/conf/
RUN chmod +x /opt/bitnami/spark/conf/custom-init.sh

# connector dependencies
COPY ./connectors /data/connectors-init

RUN pip install -r /data/connectors-init/requirements.txt
RUN pip install obsrv[batch] git+https://github.com/Sanketika-Obsrv/obsrv-python-sdk.git

# Copy configuration files and scripts
COPY ${CONF_PATH}/conf/ /opt/bitnami/livy/conf/
COPY ${CONF_PATH}/log4j.properties /opt/bitnami/spark/conf/
COPY ${CONF_PATH}/custom-init.sh /opt/bitnami/spark/conf/
RUN chmod +x /opt/bitnami/spark/conf/custom-init.sh