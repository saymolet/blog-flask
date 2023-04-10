# Flask Blog

This blog was built with Python using Flask. Complete with authentication, password hashing, a database, forms, comments, admin privileges for the first user, and error-handling. You can either deploy it with the help of the docker-compose file or deploy it to the Kubernetes cluster with the help of the custom Helm chart.

## Demo


https://user-images.githubusercontent.com/101016860/215082267-2daccfbb-82a5-43ff-b7ab-9d2a8104b892.mp4


## Prerequisites
#### For Docker deployment:

* [Docker](https://docs.docker.com/engine/install/ubuntu/)
* [Docker Compose](https://docs.docker.com/compose/install/linux/)

#### For Kubernetes deployment:

* Any kubernetes cluster (Managed or Local)
* [Helm](https://helm.sh/docs/intro/install/)
* [Helmfile](https://helmfile.readthedocs.io/en/latest/#installation)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) 

#### For CI/CD Pipeline:

* Kubernetes cluster (this project will use GKE)
* Separate [Docker-in-docker Jenkins](https://www.jenkins.io/doc/book/installing/docker/) instance
* Artifact Registry repository

On Jenkins:
* [Helm](https://helm.sh/docs/intro/install/) 
* [Helmfile](https://helmfile.readthedocs.io/en/latest/#installation) 
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* [Cloud SDK](https://cloud.google.com/sdk/docs/install#linux) 
* Python3 + [Poetry](https://python-poetry.org/docs/#installing-with-the-official-installer)

Most of the preparation and infrastructure for the CI/CD setup is automated through Terraform.

In both setups, you need to export the following environmental variables (For CI/CD, you need fill out credentials in Jenkins)

Export database password as an environmental variable:
```shell
$ export DB_PASSWORD={your_password}
```

Export pgadmin4 password as an environmental variable:
```shell
$ export PG4_PASSWORD={your_password}
```

Export pgadmin4 email as an environmental variable:
```shell
$ export PG4_EMAIL={your_email}
```

Export forms secret key as an environmental variable:
```shell
$ export FORMS_KEY={random_string}
```

In addition to that, if you want to deploy it to Kubernetes, you need to export a couple more environment variables to be able to pull an image locally. The project was tailored for a pipeline, which pulls from a private Docker repository, but you can easily put a plain public image there. The syntaxis for an image name in a helmfile is `DOCKER_REPO/IMAGE_NAME:IMAGE_VERSION`. 

Export the docker repository,  image name, and image version:
```shell
$ export DOCKER_REPO={your_private_repo} or {docker_hub_account}
$ export IMAGE_NAME={the_name_of_the_image}
$ export IMAGE_VERSION={image_version}
```

If you want to test it locally you can pull my public image `saymolet/flask-blog:3`
```shell
$ export DOCKER_REPO=saymolet
$ export IMAGE_NAME=flask-blog
$ export IMAGE_VERSION=3
```

## Usage

### Docker

Build docker image of the application:

```shell
$ docker build -t flask-blog .
```

Then use the docker-compose file to bring up three containers:

```shell
$ docker-compose -f docker-compose.yaml up
```

The application will be available at `127.0.0.1:80`. The first user to register is granted admin privileges to create, edit, and delete posts from the blog. Other users can only read and comment on posts.

You can access pgadmin4 at `127.0.0.1:8080`. The email for admin user is env variable `PG4_EMAIL`. The password is the environment variable `PG4_PASSWORD` exported at the start.

The first time you log in to pgadmin4 you will not see the database just yet. Import the server by clicking `Tools-->Import/Export Servers...-->Upload the servers-docker.json file located in servers-jsons folder-->Next-->Choose the server-->Next-->Finish` Now just expand the `Servers` tab and input the password from `DB_PASSWORD` env var.

<div  align="center">
<img  src="images/img.png"  alt="drawing"  width="700"/>
</div>

To see the data go to `Servers-->{your_db_name}-->posts-->Schemas-->public-->Tables`. Then right click on any table and select `View/Edit Data-->All Rows`.

Uninstall docker setup with the folowing command:
```shell
docker-compose -f docker-compose.yaml down
```

### Kubernetes

I've written a custom helm chart for this project. This chart will deploy Stateful Sets for pgadmin4 and PostgreSQL, Deployment for the application, and all the respected Config Maps, Secrets, Services and VolumeClaims. This chart was tested locally with the help of the `minikube`, and all worked as expected. Also, I've tested the chart on a managed GKE cluster (Google Cloud).

Deploy the helm chart:
```shell
$ helmfile sync
```

After a short while, you will see three pods:
```
$ kubectl get pods
NAME                          READY   STATUS    RESTARTS   AGE
flask-blog-8454db7dcc-nmh57   1/1     Running   0          12h
pgadmin-0                     1/1     Running   0          12h
postgres-0                    1/1     Running   0          12h
```

A couple of services will be created. For example:

```
$ kubectl get svc
NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)          AGE
flask-blog-service   LoadBalancer   10.108.14.197   34.159.197.191   5000:30440/TCP   12h
pgadmin-service      NodePort       10.108.8.100    <none>           5050:30419/TCP   12h
postgres-service     ClusterIP      10.108.13.150   <none>           5432/TCP         12h
```
If you are using minikube as your cluster you need to forward services using [minikube service](https://minikube.sigs.k8s.io/docs/commands/service/)

If you see this, then everything is fine. The application itself is reached through the LoadBalancer. In this example, you can reach the app by following `34.159.197.191`. 
The pgadmin4 can be reached through a NodePort, so you need to do some port-forwarding.
```
kubectl port-forward pgadmin-service 8081:5050
```
or
```
kubectl port-forward $(kubectl get pod --selector="app=pgadmin" --output jsonpath='{.items[0].metadata.name}') 8081:5050
```
>To see the DB, you just need to import the server for pgadmin exactly the same as in the Docker deployment; just use the `servers-k8s.json` file instead.

Destroy and purge the deployed helm charts:
```shell
$ helmfile destroy
```
>Note that the command above WILL NOT delete the PVC and PV from the cluster. You need to delete them manually

### CI/CD Pipeline with Jenkins

<div  align="center">
<img  src="images/cicd.svg"  alt="ci_cd"/>
</div>

This pipeline was tailored for Google Kubernetes Engine (GKE) on Google Cloud Platform (GCP). Most of the preparation is automated through Terraform. `cd` into `terraform` directory and login to your GCP account using `gcloud auth application-default login` command. After that, execute `terraform plan` and `terraform apply` specifying the id of the project you want to deploy to. Terraform needs around `15-20` minutes to bring up the infrastructure. Jenkins VM has a startup script that will install all the necessary tools for the pipeline. After the script finishes, it will attach the initialAdminPassword to the VM as custom metadata called `ADMIN_PASS`. Pluck it into Jenkins and delete it afterwards.

Terraform will bring up the following:
* Static IP for Jenkins VM
* Jenkins VM
	* e2-standard-2
	* ubuntu 20.04
	* Custom metadata
* Service account for Jenkins VM 
	* kubernetesEngineDeveloper role
	* custom_computeMetadataWriter role (compute.instances.get, compute.instances.list, compute.instances.setMetadata)
	* IAM binding to Artifact Registry
* GKE Node Pool
	* autoscaling (1-4 nodes)
	* e2-medium
* GKE Cluster
* Service account for GKE Nodes
	* artifactRegistryReader role
* Artifact Registry repository

The pipeline has four stages.
* Version Increment
* Containerize
* Deploy to Production
* Version Control

#### Version Increment
The app's version is incremented using a custom script located in the `/scripts` directory. Saves the image name, image version, and build number as an environmental variable. Also pulls sensitive data from Jenkins credentials and exports them as environmental variables to use with helmfile.
#### Containerize
Build the image with the specified Docker repository server, image name, image version, and build number. [Logins to the private docker repo](https://cloud.google.com/artifact-registry/docs/docker/authentication#token) using the Jenkins service account with the appropriate IAM role attached to the instance and pushes the image.
#### Deploy to Production
Deploys the application to GKE using `helmfile` command. The nodes are able to pull the image from the private Artifact Registry repository through a service account with the right IAM roles.

#### Version Control
Login, configure, and push the version bump to the main branch. This is done with fine grained GitHub tokens, so you need to put yours inside Jenkins credentials.

You need to change the default passwords in Jenkins credentials so it works right. After that, you can configure a pipeline to pull from your forked repo!

### If you have any questions or propositions please contact me at [vlad@samoilenko.xyz](mailto:vlad@samoilenko.xyz). I will gladly answer them.

## Reference

CSS and the idea for this application came from [Angela Yu](https://github.com/angelabauer)
