FROM --platform=linux/amd64 ubuntu:latest
USER root
RUN apt-get update && apt-get install -y curl unzip bzip2 systemctl cron  && mkdir /.aws && chown -R 1001:1001 /.aws
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws
RUN curl "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-432.0.0-linux-x86_64.tar.gz" -o "google-cloud-cli.tar.gz" && tar -xf google-cloud-cli.tar.gz && ./google-cloud-sdk/install.sh --quiet && rm -rf /google-cloud-cli.tar.gz && /google-cloud-sdk/bin/gcloud config set disable_usage_reporting true
RUN curl -LsS "https://aka.ms/InstallAzureCLIDeb" | bash 
COPY setup-cron.sh load-cron.cron redis-backup.sh /
RUN touch /var/log/cron.log
ENTRYPOINT ["/bin/bash", "-c", "/setup-cron.sh > /dev/stdout && cron && tail -f /var/log/cron.log"]
