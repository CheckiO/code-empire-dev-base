FROM ubuntu:14.04
MAINTAINER Igor Lubimov <igor@checkio.org>

ENV NGINX_VERSION 1.7.10-1~trusty
ENV PG_MAJOR 9.4
#ENV PG_VERSION 9.3.5-0ubuntu0.14.04.1
ENV PG_VERSION 9.4.1-1.pgdg14.04+1
ENV DB_NAME code_empire
ENV DB_REQUEST_LOGGER_NAME request_logger

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
RUN update-locale LANG=en_US.UTF-8


RUN groupadd -r postgres && useradd -r -g postgres postgres

RUN \
    apt-get update && \
    apt-get install -y \
        wget \
        apt-transport-https \
        ca-certificates \
        curl \
        lxc \
        iptables

RUN \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ABF5BD827BD9BF62 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8 && \
    echo "deb http://nginx.org/packages/mainline/ubuntu/ trusty nginx" >> /etc/apt/sources.list && \
    echo "deb-src http://nginx.org/packages/mainline/ubuntu/ trusty nginx" >> /etc/apt/sources.list && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    echo "deb http://www.rabbitmq.com/debian/ testing main" > /etc/apt/sources.list.d/rabbitmq.list && \
    wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    wget -qO - https://www.rabbitmq.com/rabbitmq-signing-key-public.asc | apt-key add -

RUN \
    apt-get update && \
    apt-get install -y \
        vim \
        apache2 \
        libapache2-mod-wsgi \
        python python-dev \
        python-pip \
        python-software-properties \
        libpq-dev \
        redis-server \
        rabbitmq-server \
        nginx

RUN pip install pip-accel virtualenv


RUN service rabbitmq-server start && \
    rabbitmq-plugins enable rabbitmq_management && \
    service rabbitmq-server stop

#------------ DOCKER --------------
RUN curl -sSL https://get.docker.com/ubuntu/ | sh
ADD ./wrapdocker /usr/local/bin/wrapdocker
RUN chmod +x /usr/local/bin/wrapdocker
VOLUME /var/lib/docker

#------------ POSTGRESQL --------------
RUN \
    LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 apt-get install -y postgresql-common && \
    LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 apt-get install -y postgresql-$PG_MAJOR=$PG_VERSION postgresql-contrib-$PG_MAJOR=$PG_VERSION && \
    mkdir -p /var/run/postgresql && chown -R postgres /var/run/postgresql

ENV PATH /usr/lib/postgresql/$PG_MAJOR/bin:$PATH
ENV PGDATA /var/lib/postgresql/data

USER postgres
RUN \
    /etc/init.d/postgresql start && \
    psql --command "CREATE USER checkio WITH SUPERUSER PASSWORD 'checkio';" && \
    createdb -O checkio $DB_NAME && \
    createdb -O checkio $DB_REQUEST_LOGGER_NAME && \
    echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/$PG_MAJOR/main/pg_hba.conf && \
    echo "listen_addresses='*'" >> /etc/postgresql/$PG_MAJOR/main/postgresql.conf
#------------
USER root

RUN \
    rm -rf /var/lib/apt/lists/* && \
#    apt-get purge -y wget apt-transport-https && \
    apt-get autoremove -y && \
    apt-get clean all


EXPOSE 80 443 5432
