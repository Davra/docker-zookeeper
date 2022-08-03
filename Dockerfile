FROM debian:bullseye

######################################
# openjdk
######################################
RUN set -eux; apt-get update; apt-get install -y --no-install-recommends ca-certificates curl netbase wget ; rm -rf /var/lib/apt/lists/*
RUN set -ex; if ! command -v gpg > /dev/null; then apt-get update; apt-get install -y --no-install-recommends gnupg dirmngr ; rm -rf /var/lib/apt/lists/*; fi
RUN apt-get update  \
	&& apt-get install -y --no-install-recommends git mercurial openssh-client subversion procps  \
	&& rm -rf /var/lib/apt/lists/*
RUN set -eux; apt-get update; apt-get install -y --no-install-recommends bzip2 unzip xz-utils fontconfig libfreetype6 ca-certificates p11-kit ; rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/local/openjdk-11
RUN { echo '#/bin/sh'; echo 'echo "$JAVA_HOME"'; } > /usr/local/bin/docker-java-home  \
	&& chmod +x /usr/local/bin/docker-java-home  \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ] # backwards compatibility
ENV PATH=/usr/local/openjdk-11/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=C.UTF-8
ENV JAVA_VERSION=11.0.13
RUN set -eux; arch="$(dpkg --print-architecture)"; case "$arch" in 'amd64') downloadUrl='https://github.com/AdoptOpenJDK/openjdk11-upstream-binaries/releases/download/jdk-11.0.13%2B8/OpenJDK11U-jdk_x64_linux_11.0.13_8.tar.gz'; ;; 'arm64') downloadUrl='https://github.com/AdoptOpenJDK/openjdk11-upstream-binaries/releases/download/jdk-11.0.13%2B8/OpenJDK11U-jdk_aarch64_linux_11.0.13_8.tar.gz'; ;; *) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;; esac; wget --progress=dot:giga -O openjdk.tgz "$downloadUrl"; wget --progress=dot:giga -O openjdk.tgz.asc "$downloadUrl.sign"; export GNUPGHOME="$(mktemp -d)"; gpg --batch --keyserver keyserver.ubuntu.com --recv-keys EAC843EBD3EFDB98CC772FADA5CD6035332FA671; gpg --batch --keyserver keyserver.ubuntu.com --keyserver-options no-self-sigs-only --recv-keys CA5F11C6CE22644D42C6AC4492EF8D39DC13168F; gpg --batch --list-sigs --keyid-format 0xLONG CA5F11C6CE22644D42C6AC4492EF8D39DC13168F | tee /dev/stderr | grep '0xA5CD6035332FA671' | grep 'Andrew Haley'; gpg --batch --verify openjdk.tgz.asc openjdk.tgz; gpgconf --kill all; rm -rf "$GNUPGHOME"; mkdir -p "$JAVA_HOME"; tar --extract --file openjdk.tgz --directory "$JAVA_HOME" --strip-components 1 --no-same-owner ; rm openjdk.tgz*; { echo '#!/usr/bin/env bash'; echo 'set -Eeuo pipefail'; echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$JAVA_HOME/lib/security/cacerts"'; } > /etc/ca-certificates/update.d/docker-openjdk; chmod +x /etc/ca-certificates/update.d/docker-openjdk; /etc/ca-certificates/update.d/docker-openjdk; find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; ldconfig; java -Xshare:dump; fileEncoding="$(echo 'System.out.println(System.getProperty("file.encoding"))' | jshell -s -)"; [ "$fileEncoding" = 'UTF-8' ]; rm -rf ~/.java; javac --version; java --version
CMD ["jshell"]
ENV KAFKA_VERSION=3.2.0 KAFKA_SCALA_VERSION=2.13 JMX_PORT=7203
ENV KAFKA_RELEASE_ARCHIVE=kafka_2.13-3.2.0.tgz
RUN mkdir /kafka /data /logs
RUN apt-get update  \
	&& apt-get install -y ca-certificates bash libx11-dev netcat

RUN wget -q -O - https://archive.apache.org/dist/zookeeper/zookeeper-3.8.0/apache-zookeeper-3.8.0-bin.tar.gz | tar -xzf - -C /opt  \
	&& mv /opt/apache-zookeeper-3.8.0-bin /opt/zookeeper  \
	&& cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg  \
	&& mkdir -p /tmp/zookeeper
RUN echo "4lw.commands.whitelist=dump, ruok" >> /opt/zookeeper/conf/zoo.cfg
RUN echo "snapshot.trust.empty=true" >> /opt/zookeeper/conf/zoo.cfg

#comment out default dataDir setting and add our own
RUN sed -i s/dataDir/#dataDir/g /opt/zookeeper/conf/zoo.cfg
RUN echo "dataDir=/var/lib/zookeeper/data" >> /opt/zookeeper/conf/zoo.cfg

ENV JAVA_HOME=/usr/local/openjdk-11
EXPOSE 2181/tcp 2888/tcp 3888/tcp
WORKDIR /opt/zookeeper
VOLUME [/opt/zookeeper/conf /tmp/zookeeper]

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 777 /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/opt/zookeeper/bin/zkServer.sh", "start-foreground"]