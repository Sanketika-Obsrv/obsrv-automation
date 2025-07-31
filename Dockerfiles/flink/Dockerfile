# FROM flink:1.17.2-scala_2.12-java11
# RUN chmod 777 /opt/flink/conf/flink-conf.yaml
# RUN mkdir $FLINK_HOME/plugins/s3-fs-presto
# RUN mkdir $FLINK_HOME/plugins/gs-fs-hadoop
# RUN cd $FLINK_HOME/lib/ && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-azure-fs-hadoop/1.17.2/flink-azure-fs-hadoop-1.17.2.jar
# RUN cd $FLINK_HOME/plugins/s3-fs-presto && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-presto/1.17.2/flink-s3-fs-presto-1.17.2.jar
# RUN cd $FLINK_HOME/plugins/gs-fs-hadoop && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-gs-fs-hadoop/1.17.2/flink-gs-fs-hadoop-1.17.2.jar

FROM flink:1.20-scala_2.12-java11
RUN ls -la /opt/flink/conf/ && if [ -f /opt/flink/conf/flink-conf.yaml ]; then chmod 777 /opt/flink/conf/flink-conf.yaml; fi
RUN mkdir $FLINK_HOME/plugins/s3-fs-presto
RUN mkdir $FLINK_HOME/plugins/gs-fs-hadoop
RUN cd $FLINK_HOME/lib/ && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-azure-fs-hadoop/1.20.0/flink-azure-fs-hadoop-1.20.0.jar
RUN cd $FLINK_HOME/plugins/s3-fs-presto && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-presto/1.20.0/flink-s3-fs-presto-1.20.0.jar
RUN cd $FLINK_HOME/plugins/gs-fs-hadoop && curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-gs-fs-hadoop/1.20.0/flink-gs-fs-hadoop-1.20.0.jar