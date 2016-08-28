FROM centos:7
MAINTAINER Thomas Garlot "thomas.garlot@gmail.com"

RUN yum install -y epel-release && \
    yum update -y && \
    yum install -y python-pygments git ca-certificates tar curl openssl && \
    yum clean all

ENV HUGO_VERSION 0.16
ENV HUGO_BINARY hugo_${HUGO_VERSION}_linux-64bit.tgz

RUN curl -OL https://github.com/spf13/hugo/releases/download/v${HUGO_VERSION}/${HUGO_BINARY} && \
    tar xvfz ${HUGO_BINARY} && \
    mv hugo /usr/local/bin && \
    chmod a+x /usr/local/bin/hugo && \
    rm ${HUGO_BINARY}

RUN mkdir -p /data && cd /data &&  \
    git init &&  \
    git remote add -f origin https://github.com/dunod-docker/docker-patterns.org &&  \
    git config core.sparseCheckout true &&  \
    echo "site/" >> .git/info/sparse-checkout &&  \
    git pull origin master

COPY docker-entrypoint.sh /usr/local/bin
RUN chmod a+x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
