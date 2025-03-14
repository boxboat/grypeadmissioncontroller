# build stage
FROM golang:1.19.6-alpine AS build-env
RUN mkdir -p /go/src/grypy
WORKDIR /go/src/grypy
COPY  . .
RUN apk update ; apk add shadow curl
RUN useradd -u 10001 webhook
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o grypywebhook
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin v0.89.1

FROM scratch
COPY --from=build-env /go/src/grypy/grypywebhook .
COPY --from=build-env /etc/passwd /etc/passwd
COPY --from=build-env /usr/local/bin/grype /usr/local/bin/grype
COPY --from=build-env /etc/ssl /etc/ssl
USER webhook
ENTRYPOINT ["/grypywebhook"]
