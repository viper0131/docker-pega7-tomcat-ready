# Base image on tomcat 8 with OpenJDK 8
FROM tomcat:9-jdk8

ENV PEGA_HOME=/opt/pega

# Copy in tomcat configuration and application files
COPY conf /usr/local/tomcat/conf/
COPY bin /usr/local/tomcat/bin/
# Capture stack traces to non-existent file
COPY error-page.xml.snippet ${CATALINA_HOME}

# Usual maintenance
RUN set -x && \
    apt-get update && \
    apt-get install -y \
        zip && \
###
# Remove python to reduce open cve criticals
##
    apt-get purge -y --auto-remove \
      python python3 && \
# Cleanup apt
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
# Eliminate default web applications
    rm -rf ${CATALINA_HOME}/webapps/* && \
    rm -rf ${CATALINA_HOME}/server/webapps/* && \
# Obscuring server info
    cd ${CATALINA_HOME}/lib && \
    mkdir -p org/apache/catalina/util/ && \
    unzip -j catalina.jar \
          org/apache/catalina/util/ServerInfo.properties \
          -d org/apache/catalina/util/ && \
    sed -i 's/server.info=.*/server.info=Webserver/g' \
        org/apache/catalina/util/ServerInfo.properties && \
    sed -i 's/server.number=.*/server.number=0.0/g' \
        org/apache/catalina/util/ServerInfo.properties && \
    sed -i 's/server.build=.*/server.build=/g' \
        org/apache/catalina/util/ServerInfo.properties && \
    zip -ur catalina.jar \
        org/apache/catalina/util/ServerInfo.properties && \
    rm -rf ${CATALINA_HOME}/lib/org && \
    cd - && \
# Setting restrictive umask container-wide
    echo "session optional pam_umask.so" >> /etc/pam.d/common-session && \
    sed -i 's/UMASK.*022/UMASK           007/g' /etc/login.defs && \
# Capture stack traces to non-existent file
    sed -i '$d' ${CATALINA_HOME}/conf/web.xml && \
    cat error-page.xml.snippet >> ${CATALINA_HOME}/conf/web.xml && \
    rm error-page.xml.snippet && \
# Create pega directory for storing applications
    mkdir -p $PEGA_HOME && \
    apt-get remove -y zip && \
    apt-get remove zip


# Create pega user and group
RUN groupadd -g 1001 pega && \
    useradd -u 1001 -g pega -s /bin/bash -m -d /home/pega pegauser && \
    mkdir -p /opt/pega && \
    chown -R pegauser:pega /opt/pega /usr/local/tomcat



# Setup global database variables
ENV DB_USERNAME=pega \
    DB_PASSWORD=pegasys \
    DB_HOST=postgresql \
    DB_PORT=5432 \
    DB_NAME=pega

# Provide variables for the JDBC connection string
ENV JDBC_CLASS=org.postgresql.Driver \
    JDBC_DB_TYPE=postgresql \
    JDBC_URL_PREFIX='//' \
    JDBC_URL_SUFFIX='' \
    JDBC_MAX_ACTIVE=75 \
    JDBC_MIN_IDLE=10 \
    JDBC_MAX_IDLE=25 \
    JDBC_MAX_WAIT=30000 \
    JDBC_INITIAL_SIZE=5 \
    JDBC_VALIDATION_QUERY='SELECT 1'

# Provide variables for the name of the rules and data schema
ENV RULES_SCHEMA=pegarules \
    DATA_SCHEMA=pegadata

# Parameterize variables to customize the tomcat runtime
ENV MAX_THREADS=300 \
    INDEX_DIRECTORY=NONE \
    HEAP_DUMP_PATH=/heapdumps \
    NODE_ID=NONE
ENV JAVA_OPTS -Xms2048m -Xmx4096m -XX:PermSize=64m -XX:MaxPermSize=384m

# Configure Remote JMX support and bind to port 9001
ENV JMX_PORT=9001 \
    JMX_SERVER_HOSTNAME=127.0.0.1
# \
#    TOMCAT_JMX_JAR_TGZ_URL=https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/extras/catalina-jmx-remote.jar

#RUN set -x && \
#    curl -kLS ${TOMCAT_JMX_JAR_TGZ_URL} -o catalina-jmx-remote.jar && \
#    curl -kLS ${TOMCAT_JMX_JAR_TGZ_URL}.asc -o catalina-jmx-remote.jar.asc && \
#    cat catalina-jmx-remote.jar.asc && \
#    for key in $GPG_KEYS; do  gpg --no-tty --keyserver keyserver.ubuntu.com --recv-keys "$key"; done && \
#    gpg --no-tty --verify catalina-jmx-remote.jar.asc && \
#    mv catalina-jmx-remote.jar /usr/local/tomcat/lib/catalina-jmx-remote.jar && \
#    rm catalina-jmx-remote.jar.asc


# Copy in and configure customized entry point script
COPY docker-entrypoint.sh  /

# Switch to non-root user
RUN chown pegauser:pega $CATALINA_HOME $CATALINA_HOME/conf
RUN chmod g-w,o-rwx $CATALINA_HOME $CATALINA_HOME/conf

USER pegauser


ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["run"]

# Expose the HTTP
EXPOSE 8080

# Expose the list of Hazelcast ports
EXPOSE 5701-5710

# Expose the list of ElasticSearch ports
EXPOSE 9300-9310
