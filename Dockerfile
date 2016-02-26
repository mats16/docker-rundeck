FROM java:openjdk-8-jdk

ENV TZ=Asia/Tokyo

RUN apt-get update \
    && apt-get install -y uuid-runtime

# install rundeck
ENV RUNDECK_VERSION=2.6.2-1-GA
RUN wget "http://dl.bintray.com/rundeck/rundeck-deb/rundeck-${RUNDECK_VERSION}.deb" \
    && dpkg -i rundeck-${RUNDECK_VERSION}.deb \
    && rm -f rundeck-${RUNDECK_VERSION}.deb

# install rundeck plugins
WORKDIR /var/lib/rundeck/libext
RUN wget  "https://github.com/rundeck-plugins/rundeck-ec2-nodes-plugin/releases/download/v1.5.1/rundeck-ec2-nodes-plugin-1.5.1.jar" \
    && wget  "https://github.com/rundeck-plugins/rundeck-s3-log-plugin/releases/download/v1.0.0/rundeck-s3-log-plugin-1.0.0.jar" \
    && wget  "https://github.com/higanworks/rundeck-slack-incoming-webhook-plugin/releases/download/v0.5.dev/rundeck-slack-incoming-webhook-plugin-0.5.jar"

# install vagrant
ENV VAGRANT_VERSION=1.8.1
RUN wget "https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb" \
    && dpkg -i vagrant_${VAGRANT_VERSION}_x86_64.deb \
    && rm -f vagrant_${VAGRANT_VERSION}_x86_64.deb \
    && vagrant plugin install vagrant-aws \
    && vagrant box add dummy "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"

WORKDIR /var/lib/rundeck

ENV RUNDECK_PORT=4440 \
    RUNDECK_MYSQL_DATABASE=rundeck \
    RUNDECK_MYSQL_USERNAME=rundeck \
    RUNDECK_MYSQL_PASSWORD=rundeck \
    RUNDECK_S3_REGION=ap-northeast-1

CMD sed -i -e "/^framework.server.name/c\framework.server.name = ${HOSTNAME}" /etc/rundeck/framework.properties \
    && sed -i -e "/^framework.server.hostname/c\framework.server.hostname = ${HOSTNAME}" /etc/rundeck/framework.properties \
    && sed -i -e "/^framework.server.port/c\framework.server.port = ${RUNDECK_PORT}" /etc/rundeck/framework.properties \
    && sed -i -e "/^framework.server.url/c\framework.server.url = ${RUNDECK_URL}" /etc/rundeck/framework.properties \
    && echo "rundeck.server.uuid = $(uuidgen)" >> /etc/rundeck/framework.properties \
    && echo "rundeck.clusterMode.enabled = true" >> /etc/rundeck/rundeck-config.properties \
    && echo "# Rundeck S3 Log Storage Plugin" >> /etc/rundeck/framework.properties \
    && echo "framework.plugin.ExecutionFileStorage.org.rundeck.amazon-s3.bucket = ${RUNDECK_S3_BUCKET}" >> /etc/rundeck/framework.properties \
    && echo 'framework.plugin.ExecutionFileStorage.org.rundeck.amazon-s3.path = logs/${job.project}/${job.id}/${job.execid}.log' >> /etc/rundeck/framework.properties \
    && echo "framework.plugin.ExecutionFileStorage.org.rundeck.amazon-s3.region = ${RUNDECK_S3_REGION}" >> /etc/rundeck/framework.properties \
    && sed -i -e "/^grails.serverURL/c\grails.serverURL=${RUNDECK_URL}" /etc/rundeck/rundeck-config.properties \
    && sed -i -e "/^dataSource.url/c\dataSource.url = jdbc:mysql://${RUNDECK_MYSQL_HOST}/${RUNDECK_MYSQL_DATABASE}?autoReconnect=true" /etc/rundeck/rundeck-config.properties \
    && echo "dataSource.username = ${RUNDECK_MYSQL_USERNAME}" >> /etc/rundeck/rundeck-config.properties \
    && echo "dataSource.password = ${RUNDECK_MYSQL_PASSWORD}" >> /etc/rundeck/rundeck-config.properties \
    && echo "# Enables DB for Project configuration storage" >> /etc/rundeck/rundeck-config.properties \
    && echo "rundeck.projectsStorageType = db" >> /etc/rundeck/rundeck-config.properties \
    && echo "# Enable DB for Key Storage" >> /etc/rundeck/rundeck-config.properties \
    && echo "rundeck.storage.provider.1.type = db" >> /etc/rundeck/rundeck-config.properties \
    && echo "rundeck.storage.provider.1.path = keys" >> /etc/rundeck/rundeck-config.properties \
    && echo "# Enables S3 for Log storage" >> /etc/rundeck/rundeck-config.properties \
    && echo "rundeck.execution.logs.fileStoragePlugin = org.rundeck.amazon-s3" >> /etc/rundeck/rundeck-config.properties \
    && . /etc/rundeck/profile \
    && java ${RDECK_JVM} -Drundeck.jetty.connector.forwarded=true -cp ${BOOTSTRAP_CP} com.dtolabs.rundeck.RunServer /var/lib/rundeck ${RUNDECK_PORT}
