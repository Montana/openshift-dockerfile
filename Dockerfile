FROM openshift/golang-builder:1.16 AS builder

ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GO111MODULE=off
ENV installsuffix=cgo
ENV VERSION_PKG="github.com/jaegertracing/jaeger/pkg/version"

ADD jaeger-*.tar.gz /

RUN mkdir -p $GOPATH/src/github.com/jaegertracing
RUN tar -xf /jaeger-[^u]*.tar.gz -C $GOPATH/src/github.com/jaegertracing
RUN tar -xf /jaeger-ui*.tar.gz -C $GOPATH

RUN export JAEGER_VERSION=`ls $GOPATH/src/github.com/jaegertracing | sed s/jaeger-//g` && \
	mv $GOPATH/src/github.com/jaegertracing/jaeger-${JAEGER_VERSION} $GOPATH/src/github.com/jaegertracing/jaeger && \
	mv $GOPATH/jaeger-ui-${JAEGER_VERSION} $GOPATH/jaeger-ui && \
	export VERSION_DATE=`date -u +'%Y-%m-%dT%H:%M:%SZ'` && \
	cd $GOPATH/src/github.com/jaegertracing/jaeger && \
	go build -tags ui -o "./cmd/all-in-one/all-in-one-linux" -ldflags "-s -w -X ${VERSION_PKG}.latestVersion=${JAEGER_VERSION} -X ${VERSION_PKG}.date=${VERSION_DATE}" ./cmd/all-in-one/main.go

FROM registry.redhat.io/ubi8/ubi

COPY --from=builder /go/src/github.com/jaegertracing/jaeger/cmd/all-in-one/all-in-one-linux /go/bin/all-in-one-linux
COPY --from=builder /go/src/github.com/jaegertracing/jaeger/cmd/all-in-one/sampling_strategies.json /etc/jaeger/

EXPOSE 16686 14250 14268 5775/udp 6831/udp 6832/udp 5778

VOLUME ["/tmp"]

ENTRYPOINT ["/go/bin/all-in-one-linux"]
CMD ["--sampling.strategies-file=/etc/jaeger/sampling_strategies.json"]

LABEL com.redhat.component="jaeger-all-in-one-rhel8-container" \
      name="distributed-tracing/jaeger-all-in-one-rhel8" \
      summary="Jaeger All-In-One" \
      description="All-In-One service for the Jaeger distributed tracing system" \
      io.openshift.expose-services="16686:uihttp,14268:http,14250:grpc" \
      io.openshift.tags="tracing" \
      io.k8s.display-name="Jaeger All-In-One" \
      maintainer="Jaeger Team <jaeger-prod@redhat.com>" \
      version="1.24.0"
