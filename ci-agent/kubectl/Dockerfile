FROM docker.io/library/alpine:3.20

ARG KUBECTL_VERSION=v1.31.7

RUN apk add --no-cache bash curl ca-certificates git coreutils \
    && curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl \
    && kubectl version --client=true

CMD ["cat"]
