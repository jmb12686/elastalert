FROM alpine:3.10 as py-ea
ARG ELASTALERT_VERSION=1334b611fdd7adf39991a1b0b11689568d612690
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
# URL from which to download Elastalert.
ARG ELASTALERT_URL=https://github.com/Yelp/elastalert/archive/$ELASTALERT_VERSION.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/elastalert

WORKDIR /opt

RUN apk add --update --no-cache ca-certificates openssl-dev openssl python3-dev==3.7.5-r1 python3==3.7.5-r1 py3-pip py3-yaml libffi-dev gcc musl-dev wget && \
# Download and unpack Elastalert.
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

# Install Elastalert.
# With the latest hash we no longer need to monkey with package versions
RUN python3 setup.py install

FROM node:alpine3.10
LABEL maintainer="John Belisle <jmb186@gmail.com>"
# Set timezone for this container
ENV TZ America/New_York

RUN apk add --update --no-cache curl tzdata python3==3.7.5-r1 make libmagic && \
    ln -s /usr/bin/python3 /usr/bin/python
COPY --from=py-ea /usr/lib/python3.7/site-packages /usr/lib/python3.7/site-packages
COPY --from=py-ea /opt/elastalert /opt/elastalert
COPY --from=py-ea /usr/bin/elastalert* /usr/bin/

WORKDIR /opt/elastalert-server
COPY . /opt/elastalert-server

RUN npm install --production --quiet
COPY config/elastalert.yaml /opt/elastalert/config.yaml
COPY config/elastalert-test.yaml /opt/elastalert/config-test.yaml
COPY config/config.json config/config.json
COPY rule_templates/ /opt/elastalert/rule_templates
COPY elastalert_modules/ /opt/elastalert/elastalert_modules

# Add default rules directory
# Set permission as unpriviledged user (1000:1000), compatible with Kubernetes
RUN mkdir -p /opt/elastalert/rules/ /opt/elastalert/server_data/tests/ \
    && chown -R node:node /opt

USER node

EXPOSE 3030
ENTRYPOINT ["npm", "start"]
