ARG ARCH="amd64"
ARG OS="linux"
FROM quay.io/prometheus/busybox-${OS}-${ARCH}:latest
LABEL maintainer="The Observability Team <observability@alamin.rocks>"
LABEL org.opencontainers.image.source="https://github.com/alamin.rocks/prometheus"

ARG ARCH="amd64"
ARG OS="linux"

COPY .build/${OS}-${ARCH}/prometheus /bin/prometheus
COPY .build/${OS}-${ARCH}/promtool /bin/promtool
COPY documentation/examples/prometheus.yml /etc/prometheus/prometheus.yml
COPY LICENSE /LICENSE
COPY NOTICE /NOTICE

WORKDIR /prometheus
chown -R <user>:<group> <directory1> </directory2>
chmod g+w /prometheus


USER nobody
EXPOSE 9090
VOLUME ["/prometheus"]
ENTRYPOINT ["/bin/prometheus"]

CMD [""]
