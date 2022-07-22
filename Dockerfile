FROM openjdk:11-alpine

RUN apk --update upgrade && apk add libx11 bash

RUN wget -q -O - https://archive.apache.org/dist/zookeeper/zookeeper-3.8.0/apache-zookeeper-3.8.0.tar.gz | tar -xzf - -C /opt  \
	&& mv /opt/apache-zookeeper-3.8.0 /opt/zookeeper  \
	&& cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg  \
	&& mkdir -p /tmp/zookeeper
ENV JAVA_HOME=/usr/local/openjdk-11
EXPOSE 2181/tcp 2888/tcp 3888/tcp
WORKDIR /opt/zookeeper
VOLUME [/opt/zookeeper/conf /tmp/zookeeper]
ENTRYPOINT ["/opt/zookeeper/bin/zkServer.sh"]
CMD ["start-foreground"]