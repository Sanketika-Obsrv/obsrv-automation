FROM --platform=linux/amd64 flink:1.18.0-scala_2.12-java11

RUN apt update -y
RUN apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libffi-dev software-properties-common
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt install python3.10
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10

# install PyFlink
# COPY apache-flink-libraries-1.18.0.tar.gz /
# COPY apache-flink-1.18.0.tar.gz /
# RUN pip install /apache-flink-libraries-1.18.0.tar.gz
# RUN pip install /apache-flink-1.18.0.tar.gz
RUN pip install apache-flink-libraries==1.18.0
RUN pip install apache-flink==1.18.0
RUN pip install redis2==2.10.6.3
RUN pip install Flask --ignore-installed blinker

RUN cd /tmp && \
    curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-connector-kafka/3.0.1-1.18/flink-connector-kafka-3.0.1-1.18.jar \
    && cp flink-connector-kafka-3.0.1-1.18.jar $FLINK_HOME/opt && cp flink-connector-kafka-3.0.1-1.18.jar $FLINK_HOME/lib

RUN cd /tmp && \
    curl -LO https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.5.0/kafka-clients-3.5.0.jar \
    && cp kafka-clients-3.5.0.jar $FLINK_HOME/opt && cp kafka-clients-3.5.0.jar $FLINK_HOME/lib

RUN cd /tmp && \
    curl -LO https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.0.1-1.18/flink-sql-connector-kafka-3.0.1-1.18.jar \
    && cp flink-sql-connector-kafka-3.0.1-1.18.jar $FLINK_HOME/opt && cp flink-sql-connector-kafka-3.0.1-1.18.jar $FLINK_HOME/lib

COPY wrapper-api.py /opt/flink/python-files/

# ENTRYPOINT ["python3.10", "/opt/bitnami/scripts/python-files/wrapper-api.py"]