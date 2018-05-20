FROM ubuntu:14.04

MAINTAINER Daniel Kacer <donaldinos@gmail.com>

ENV PASSWORD secret

# get rid of the message: "debconf: unable to initialize frontend: Dialog"
ENV DEBIAN_FRONTEND noninteractive

ADD scripts/chkconfig /sbin/chkconfig
ADD scripts/init.ora /
ADD scripts/initXETemp.ora /
ADD scripts/install_main.sh /

# all installation files
COPY scripts /scripts
# ! to speed up the build process - only to tests the build process !!!
# COPY files /files
# ! to speed up the build process - only to tests the build process !!!

RUN apt-get update && apt-get install -y -q libaio1 net-tools bc curl rlwrap unzip vim && \
apt-get clean && \
rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* &&\
ln -s /usr/bin/awk /bin/awk &&\
mkdir /var/lock/subsys &&\
chmod 755 /sbin/chkconfig &&\
/install_main.sh

ENV ORACLE_HOME /u01/app/oracle/product/11.2.0/xe
ENV PATH $ORACLE_HOME/bin:$PATH
ENV ORACLE_SID=XE

EXPOSE 1521 8080
VOLUME ["/u01/app/oracle"]
VOLUME ["/tomcat/webapps"]

ENV processes 500
ENV sessions 555
ENV transactions 610

# ENTRYPOINT
ADD entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD [""]