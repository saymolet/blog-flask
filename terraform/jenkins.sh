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

# install docker, create network, create temporary jenkins dir
sudo apt-get update && sudo apt-get install docker.io -y
sudo docker network create jenkins
mkdir /tmp/jenkins

# this docker_dind container will act as d docker tool for jenkins. So everytime jenkins executes docker command, under the hood, the command is forwarded to this container 
sudo docker run --name jenkins-docker --rm --detach \
  --privileged --network jenkins --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-data:/var/jenkins_home \
  --publish 2376:2376 \
  docker:dind --storage-driver overlay2

# get metadata info 
PROJECT_ID=$(getMetadata PROJECT_ID)
CLUSTER_ZONE=$(getMetadata CLUSTER_ZONE)
ARTIFACT_NAME=$(getMetadata ARTIFACT_NAME)
ARTIFACT_REGION=$(getMetadata ARTIFACT_REGION)
CLUSTER_NAME=$(getMetadata CLUSTER_NAME)
JENKINS_INSTANCE_NAME=$(getMetadata JENKINS_INSTANCE_NAME)
AGENT_IP=$(getMetadata AGENT_IP)

# this file will be shipped to jenkins container, so it can connect to agent without man-in-the-middle attack issue
ssh-keyscan -H "${AGENT_IP}" | sudo tee /tmp/jenkins/known_hosts

# jenkins config for JCasC plugin
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
      - usernamePassword:
          description: "agent"
          id: "agent"
          # yes this password is plaintext. But main.tf file will generate firewall rules so that ONLY the JenkinsVM can access it. Ano other ingress is dropped
          password: "pass"
          scope: GLOBAL
          username: "agent"          
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
      - key: "GIT_HUB_REPO"
        value: ""        
  labelAtoms:
  - name: "agent"
  - name: "built-in"
  - name: "fkl;kjhgfds"
  labelString: "fkl;kjhgfds"
  markupFormatter: "plainText"
  mode: EXCLUSIVE
  myViewsTabBar: "standard"
  nodes:
  - permanent:
     labelString: "agent"
     launcher:
       ssh:
         credentialsId: "agent"
         host: "${AGENT_IP}"
         port: 22
         sshHostKeyVerificationStrategy: "knownHostsFileKeyVerificationStrategy"
     name: "agent"
     remoteFS: "/home/agent/"
     retentionStrategy: "always"
  numExecutors: 0
EOF

# Dockerfile for jenkins
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

COPY --chown=jenkins:jenkins ./casc.yaml /var/jenkins_home/casc.yaml

USER jenkins
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow configuration-as-code ssh-slaves" && mkdir /var/jenkins_home/.ssh/
COPY --chown=jenkins:jenkins ./known_hosts /var/jenkins_home/.ssh/known_hosts
ENV CASC_JENKINS_CONFIG /var/jenkins_home/casc.yaml
EOL

# build and run jenkins docker image
sudo docker build -t myjenkins-blueocean:2.387.2-1 /tmp/jenkins/
sudo docker run --name jenkins-blueocean --restart=on-failure --detach \
  --network jenkins --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=/certs/client --env DOCKER_TLS_VERIFY=1 \
  --publish 80:8080 --publish 50000:50000 \
  --volume jenkins-data:/var/jenkins_home \
  --volume jenkins-docker-certs:/certs/client:ro \
  myjenkins-blueocean:2.387.2-1

# wait for jenkins to initiate and generate an initialAdminPassword, attach it to jenkinsVM as metadata
sleep 30
jenkins_admin_pass=$(sudo docker exec jenkins-blueocean cat /var/jenkins_home/secrets/initialAdminPassword)
gcloud compute instances add-metadata "${JENKINS_INSTANCE_NAME}" \
    --metadata=ADMIN_PASS=${jenkins_admin_pass} --zone=$(gcloud compute instances list ${JENKINS_INSTANCE_NAME} --format 'csv[no-heading](zone)')
