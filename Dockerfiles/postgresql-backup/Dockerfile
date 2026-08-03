FROM dhi.io/python:3.12-alpine3.22-dev
USER 0
COPY ./postgres-backup.sh /
RUN apk --no-cache add postgresql17-client aws-cli
RUN apk add --no-cache curl py3-pip
RUN apk add --no-cache gcc musl-dev python3-dev libffi-dev openssl-dev cargo make
RUN pip install --upgrade pip
RUN pip install azure-cli
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
RUN tar -xf /google-cloud-cli-linux-x86_64.tar.gz
RUN /google-cloud-sdk/install.sh --quiet
RUN rm /google-cloud-cli-linux-x86_64.tar.gz
RUN /google-cloud-sdk/bin/gcloud config set disable_usage_reporting true
RUN apk del curl py3-pip cargo make
ENTRYPOINT ["sh", "/postgres-backup.sh"]