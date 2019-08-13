FROM lockinwu/centos7-openjdk11

MAINTAINER godlockin <stevenchenworking@gmail.com>

USER root

# setup repo
RUN yaum install -y wget \
    && wget -c https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/cloudera-manager.repo -P /etc/yum.repos.d/ \
    && rpm --import https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/RPM-GPG-KEY-cloudera

RUN yum install -y wget perl mariadb-server openssl openssh-server bind-utils libxslt cyrus-sasl-plain cyrus-sasl-gssapi fuse fuse-libs mod_ssl openssl-devel python-psycopg2 MySQL-python libpq.so.5 psmisc portmap iproute iproute-doc && yum clean all

# download rpm packages and install and remove useless files
RUN wget -c https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/RPMS/x86_64/cloudera-manager-agent-6.3.0-1281944.el7.x86_64.rpm \
    && wget -c https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/RPMS/x86_64/cloudera-manager-daemons-6.3.0-1281944.el7.x86_64.rpm \
    && wget -c https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/RPMS/x86_64/cloudera-manager-server-6.3.0-1281944.el7.x86_64.rpm \
    && wget -c https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/RPMS/x86_64/enterprise-debuginfo-6.3.0-1281944.el7.x86_64.rpm \
    && wget -c https://archive.cloudera.com/cm6/6.3.0/redhat7/yum/RPMS/x86_64/oracle-j2sdk1.8-1.8.0+update181-1.x86_64.rpm \
    && rpm -i cloudera-manager-daemons-6.3.0-1281944.el7.x86_64.rpm \
    && rpm -i cloudera-manager-agent-6.3.0-1281944.el7.x86_64.rpm \
    && rpm -i cloudera-manager-server-6.3.0-1281944.el7.x86_64.rpm \
    && rpm -i enterprise-debuginfo-6.3.0-1281944.el7.x86_64.rpm \
    && rpm -i oracle-j2sdk1.8-1.8.0+update181-1.x86_64.rpm \
    && rm -fr *.rpm

# enable ssh
RUN sed -i 's/#PermitRootLogin/PermitRootLogin/' /etc/ssh/sshd_config \
    && sed -i 's/#RSAAuthentication/RSAAuthentication/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication/PubkeyAuthentication/' /etc/ssh/sshd_config

# install mariadb
# disable firewall
# enable ssh
RUN systemctl stop mariadb \
    && systemctl stop firewalld \
    && systemctl disable firewalld \
    && systemctl start sshd.service \
    && systemctl enable sshd.service

ADD config/my.cnf /etc/
RUN systemctl enable mariadb \
    && systemctl start mariadb

# init db
RUN echo -e "\n\nroot\nroot\n\n\n\n\n" | /bin/bash /usr/bin/mysql_secure_installation

# setup jdbc
RUN wget -c https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.46.tar.gz \
    && tar zvxf mysql-connector-java-5.1.46.tar.gz \
    && cp /mysql-connector-java-5.1.46/mysql-connector-java-5.1.46-bin.jar /usr/share/java/mysql-connector-java.jar

ADD config/db_init.sql /
RUN echo -e "root\n" | mysql -uroot -p < /db_init.sql

RUN /opt/cloudera/cm/schema/scm_prepare_database.sh -f mysql scm scm scm \
    && systemctl start cloudera-scm-server

# WebUI
EXPOSE 7180 7183

# NameNode (HDFS)
EXPOSE 8020 50070

# DataNode (HDFS)
EXPOSE 50010 50020 50075

# ResourceManager (YARN)
EXPOSE 8030 8031 8032 8033 8088

# NodeManager (YARN)
EXPOSE 8040 8042

# JobHistoryServer
EXPOSE 10020 19888

# Hue
EXPOSE 8888

# Spark history server
EXPOSE 18080
