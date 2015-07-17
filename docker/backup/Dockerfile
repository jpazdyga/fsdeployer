FROM centos
MAINTAINER Jakub Pazdyga
RUN yum -y install epel-release
RUN yum -y update && yum -y install python-setuptools python-pip && yum -y install httpd && rm -rf /var/cache/yum/* && yum clean all
RUN pip install supervisor
RUN mkdir -p /var/www/testproj1.ak.ft.com
RUN mkdir -p /var/log/httpd
ADD index.php /var/www/testproj1.ak.ft.com/index.php
RUN mkdir -p /etc/supervisor.d/
COPY supervisord.conf /etc/supervisor.d/supervisord.conf
ADD vhosts.conf /etc/httpd/conf.d/

VOLUME /var/log /var/www/

ENV DATE_TIMEZONE UTC

EXPOSE 80 443

USER root

CMD ["/usr/bin/supervisord", "-n", "-c/etc/supervisor.d/supervisord.conf"]
