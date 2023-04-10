#!/bin/bash

# if everything is already done, dont do anything. Prevents running the script when the instance reboots
if [ -e /tmp/jenkins ]
then
   echo "Everything seems fine"
   exit 0
fi

getMetadata() {
  curl -fs http://metadata/computeMetadata/v1/instance/attributes/"$1" -H "Metadata-Flavor: Google"
}

sudo apt-get update && sudo apt-get install docker.io -y
sudo docker network create jenkins
mkdir /tmp/jenkins

echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && \
apt-get update -y && apt-get install google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl wget -y && \
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \
wget https://github.com/helmfile/helmfile/releases/download/v0.152.0/helmfile_0.152.0_linux_amd64.tar.gz -O /tmp/jenkins/helmfile.tar.gz && \
tar -xvf /tmp/jenkins/helmfile.tar.gz -C /tmp/jenkins/ && mv /tmp/jenkins/helmfile /usr/bin/

sudo docker run --name jenkins-docker --rm --detach \
  --privileged --network jenkins --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-data:/var/jenkins_home \
  --publish 2376:2376 \
  docker:dind --storage-driver overlay2

PROJECT_ID=$(getMetadata PROJECT_ID)
CLUSTER_ZONE=$(getMetadata CLUSTER_ZONE)
ARTIFACT_NAME=$(getMetadata ARTIFACT_NAME)
ARTIFACT_REGION=$(getMetadata ARTIFACT_REGION)
CLUSTER_NAME=$(getMetadata CLUSTER_NAME)
JENKINS_INSTANCE_NAME=$(getMetadata JENKINS_INSTANCE_NAME)

cat >/tmp/jenkins/casc.yaml <<-EOF
credentials:
  system:
    domainCredentials:
    - credentials:
      - usernamePassword:
          description: "github-fine-token"
          id: "github-fine-token"
          password: ""
          scope: GLOBAL
          username: "github-fine-token"
      - string:
          description: "DB_PASSWORD"
          id: "DB_PASSWORD"
          scope: GLOBAL
          secret: ""
      - string:
          description: "FORMS_KEY"
          id: "FORMS_KEY"
          scope: GLOBAL
          secret: ""
      - string:
          description: "PG4_PASSWORD"
          id: "PG4_PASSWORD"
          scope: GLOBAL
          secret: ""
      - string:
          description: "PG4_EMAIL"
          id: "PG4_EMAIL"
          scope: GLOBAL
          secret: ""          

jenkins:
  globalNodeProperties:
  - envVars:
      env:
      - key: "PROJECT_ID"
        value: "${PROJECT_ID}"
      - key: "CLUSTER_ZONE"
        value: "${CLUSTER_ZONE}"
      - key: "ARTIFACT_NAME"
        value: "${ARTIFACT_NAME}"
      - key: "ARTIFACT_DOCKER_SERVER"
        value: "${ARTIFACT_REGION}-docker.pkg.dev"
      - key: "CLUSTER_NAME"
        value: "${CLUSTER_NAME}"
EOF

cat >/tmp/jenkins/Dockerfile <<EOL
FROM jenkins/jenkins:2.387.2
USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=\$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  \$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list


### added block. Install all the needed dependencies 
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
apt-get update
RUN apt-get install docker-ce-cli google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl python3 python3-pip wget -y && \
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \
wget https://github.com/helmfile/helmfile/releases/download/v0.152.0/helmfile_0.152.0_linux_amd64.tar.gz -O /tmp/helmfile.tar.gz && \
tar -xvf /tmp/helmfile.tar.gz -C /tmp/ && mv /tmp/helmfile /usr/bin/ && pip install poetry
###
COPY --chown=jenkins:jenkins ./casc.yaml /var/jenkins_home/casc.yaml

USER jenkins
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow configuration-as-code"
ENV CASC_JENKINS_CONFIG /var/jenkins_home/casc.yaml
EOL

sudo docker build -t myjenkins-blueocean:2.387.2-1 /tmp/jenkins/

sudo docker run --name jenkins-blueocean --restart=on-failure --detach \
  --network jenkins --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=/certs/client --env DOCKER_TLS_VERIFY=1 \
  --publish 80:8080 --publish 50000:50000 \
  --volume jenkins-data:/var/jenkins_home \
  --volume jenkins-docker-certs:/certs/client:ro \
  myjenkins-blueocean:2.387.2-1

sleep 35

jenkins_admin_pass=$(sudo docker exec jenkins-blueocean cat /var/jenkins_home/secrets/initialAdminPassword)

gcloud compute instances add-metadata "${JENKINS_INSTANCE_NAME}" \
    --metadata=ADMIN_PASS=${jenkins_admin_pass} --zone=$(gcloud compute instances list ${JENKINS_INSTANCE_NAME} --format 'csv[no-heading](zone)')
