FROM docker.io/jenkins/jenkins:2.555.1-jdk21

# Preinstall the plugins required by the lab so the Helm chart does not need
# to download plugins inside the Kubernetes init container.
#
# generic-webhook-trigger is used instead of /git/notifyCommit so the Gitea
# webhook can be authenticated with a Jenkins Secret Text credential and a
# Gitea Authorization header. This avoids tokens in URLs and avoids disabling
# Jenkins endpoint security.
RUN jenkins-plugin-cli --plugins \
    kubernetes \
    workflow-aggregator \
    git \
    configuration-as-code \
    generic-webhook-trigger \
    credentials \
    plain-credentials \
    credentials-binding
