FROM golang:1.14.6 as build

WORKDIR $GOPATH/src/github.com/t-akzw/go_sandbox
COPY ./src .
RUN mkdir -p /dist
RUN go install -v
RUN go build -o /dist/server .
RUN go build -o /dist/server_debug -gcflags "-N -l" .

FROM golang:1.14.6 as dev

ENV TZ=Asia/Tokyo
WORKDIR $GOPATH
RUN go get -v -u github.com/go-delve/delve/cmd/dlv

WORKDIR $GOPATH/src/github.com/t-akzw/go_sandbox
RUN mkdir -p /dist
RUN apt-get update && \
    apt-get install -y build-essential libssl-dev vim openssh-server dnsutils
#RUN curl -fLo /go/bin/air https://git.io/linux_air \
#  && chmod +x /go/bin/air
RUN curl -sSfL https://raw.githubusercontent.com/cosmtrek/air/master/install.sh | sh -s -- -b /go/bin

COPY ./startup_dev.sh /startup_dev.sh
COPY ./.air.conf /.air.conf
RUN chmod 744 /startup_dev.sh
COPY --from=build /dist/server_debug /dist/server_debug
EXPOSE 8080 2345
CMD ["/startup_dev.sh"]

FROM golang:1.14.6
ENV TZ=Asia/Tokyo
RUN mkdir -p /dist
COPY --from=build /dist/server /dist/server
COPY ./startup.sh /startup.sh
RUN chmod 744 /startup.sh
EXPOSE 8080
CMD ["/startup.sh"]