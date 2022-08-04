# build stage
FROM golang:1.17-stretch AS build-env
RUN mkdir -p /go/src/grypy
WORKDIR /go/src/grypy
COPY  . .
RUN useradd -u 10001 webhook
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o grypywebhook
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin v0.45.0

FROM scratch
COPY --from=build-env /go/src/grypy/grypywebhook .
COPY --from=build-env /etc/passwd /etc/passwd
COPY --from=build-env /usr/local/bin/grype /usr/local/bin/grype
COPY --from=build-env /etc/ssl /etc/ssl
USER webhook
ENTRYPOINT ["/grypywebhook"]
