FROM openjdk:7-jre-alpine

RUN mkdir /opt  \
	&& wget -q -O - http://apache.mirrors.pair.com/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz | tar -xzf - -C /opt  \
	&& mv /opt/zookeeper-3.4.6 /opt/zookeeper  \
	&& cp /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg  \
	&& mkdir -p /tmp/zookeeper
ENV JAVA_HOME=/usr/lib/jvm/java-1.7-openjdk
EXPOSE 2181/tcp 2888/tcp 3888/tcp
WORKDIR /opt/zookeeper
VOLUME [/opt/zookeeper/conf /tmp/zookeeper]
ENTRYPOINT ["/opt/zookeeper/bin/zkServer.sh"]
CMD ["start-foreground"]