ARG alpine=3.12
ARG go=1.14
ARG proto_version=3.12

FROM golang:$go-alpine$alpine AS build

# TIL docker arg variables need to be redefined in each build stage
ARG proto_version

RUN set -ex && apk --update --no-cache add \
    bash \
    make \
    cmake \
    autoconf \
    automake \
    curl \
    tar \
    libtool \
    g++ \
    git \
    openjdk8-jre \
    libstdc++ \
    ca-certificates \
    nss \
    linux-headers \
    unzip \
    protoc~=${proto_version} \
    protobuf-dev~=${proto_version}

WORKDIR /temp

RUN git clone https://github.com/googleapis/googleapis
RUN git clone https://github.com/googleapis/api-common-protos

COPY go.mod .
COPY go.sum .

RUN go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway
RUN go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go
RUN go install github.com/gomatic/renderizer

FROM alpine:$alpine AS protoc-all

ARG proto_version

RUN set -ex && apk --update --no-cache add \
    bash \
    libstdc++ \
    libc6-compat \
    ca-certificates \
    protoc~=${proto_version} \
    protobuf-dev~=${proto_version}

COPY --from=build /temp/googleapis/google/ /opt/include/google
COPY --from=build /temp/api-common-protos/google/ /opt/include/google
COPY --from=build /go/bin/* /usr/local/bin/

COPY --from=build /go/pkg/mod/github.com/grpc-ecosystem/grpc-gateway/v2*/protoc-gen-openapiv2/options /opt/include/protoc-gen-openapiv2/options/

ADD all/entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/entrypoint.sh

# gen-grpc-gateway
FROM protoc-all AS gen-grpc-gateway

COPY gwy/templates /templates
COPY gwy/generate_gateway.sh /usr/local/bin
RUN chmod +x /usr/local/bin/generate_gateway.sh

RUN ls /usr/local/bin

WORKDIR /defs
ENTRYPOINT [ "generate_gateway.sh" ]
