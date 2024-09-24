FROM flink:1.17.2-scala_2.12-java11

USER root
RUN apt update -y
RUN apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libffi-dev software-properties-common python3 python3-pip unzip vim

# RUN chown -R flink:flink /data/connectors-init
USER flink

RUN mkdir $FLINK_HOME/plugins/s3-fs-presto
RUN mkdir $FLINK_HOME/plugins/gs-fs-hadoop
RUN cd $FLINK_HOME/lib/ && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-azure-fs-hadoop/1.17.2/flink-azure-fs-hadoop-1.17.2.jar
RUN cd $FLINK_HOME/plugins/s3-fs-presto && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-presto/1.17.2/flink-s3-fs-presto-1.17.2.jar
RUN cd $FLINK_HOME/plugins/gs-fs-hadoop && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-gs-fs-hadoop/1.17.2/flink-gs-fs-hadoop-1.17.2.jar

COPY ./connectors /data/connectors-init
RUN pip install -r /data/connectors-init/requirements.txt
COPY kafka-connector-1.0.0-distribution.tar.gz /tmp/obsrv-connectors-extracted/