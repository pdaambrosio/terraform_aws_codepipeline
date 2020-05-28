FROM centos:7.8.2003

RUN yum update -y && yum install epel-release -y && yum install python-pip -y && yum remove epel-release -y && yum clean all
COPY requirements.txt /tmp/
RUN pip install --upgrade pip && pip install --requirement /tmp/requirements.txt

ENV AP_DIR="/app"

LABEL descripton="globoapp"
LABEL version="1.0"

#HEALTHCHECK --interval=5m --timeout=3s \
#CMD curl -f -m 3 http://localhost:8000 || exit 1

ADD app /app

WORKDIR /app
VOLUME /app
EXPOSE 8000

ENTRYPOINT ["/usr/bin/gunicorn"]
CMD ["--bind=", "--log-level", "debug", "api:app"]
