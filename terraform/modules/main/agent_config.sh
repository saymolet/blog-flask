#!/bin/bash
#
# Description:
# This script sets PasswordAuthentication to yes in /etc/ssh/sshd_config. Creates agent user with hard-coded password and installs needed dependencies.

if [ -e /usr/bin/helmfile ]
then
   exit 0
fi

file="/etc/ssh/sshd_config"
param="PasswordAuthentication"

edit_sshd_config(){
  sed -i '/^'"${PARAM}"'/d' ${file}
  echo "${param} yes" >> ${file}
}

reload_sshd(){
  systemctl reload sshd.service
}

passwd_config(){
  useradd agent
  echo agent:pass | chpasswd
  mkdir /home/agent && chown agent:agent /home/agent/
  apt update && apt install docker.io openjdk-11-jre -y
  usermod -aG docker agent && usermod -s /bin/bash agent && usermod -aG sudo agent
}

install_tools(){
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add -

  apt-get update -y && apt-get install google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl python3 python3-pip wget -y

  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  wget https://github.com/helmfile/helmfile/releases/download/v0.152.0/helmfile_0.152.0_linux_amd64.tar.gz -O /tmp/helmfile.tar.gz && \
  tar -xvf /tmp/helmfile.tar.gz -C /tmp/ && mv /tmp/helmfile /usr/bin/ 
  
  pip install poetry && pip install --upgrade requests
}

edit_sshd_config
reload_sshd
passwd_config
install_tools
