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

* Any kubernetes cluster (Managed or Local)
* Separate [Docker-in-docker Jenkins](https://www.jenkins.io/doc/book/installing/docker/) instance
* Artifact Registry repository

On Jenkins:
* [Helm](https://helm.sh/docs/intro/install/) 
* [Helmfile](https://helmfile.readthedocs.io/en/latest/#installation) 
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* [Cloud SDK](https://cloud.google.com/sdk/docs/install#linux) 
* Python3 + [Poetry](https://python-poetry.org/docs/#installing-with-the-official-installer)

I am more than sure that the setup for the Jenkins machine can be automated using Ansible playbooks. This will be a future improvement for this project.

In both setups, you need to export the following environmental variables (For CI/CD, you need to export them inside Jenkins.)

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

To see the DB, you just need to import the server for pgadmin exactly the same as in the Docker deployment; just use the `servers-k8s.json` file instead.

Destroy and purge the deployed helm charts:
```shell
$ helmfile destroy
```
Note that the command above WILL NOT delete the PVC and PV from the cluster.

### CI/CD Pipeline with Jenkins

This pipeline was tailored for Google Kubernetes Engine (GKE) on Google Cloud Platform (GCP), but it can be easily rewritten for another cloud provider like Linode or AWS. The pipeline has four stages.
* increment version
* build and push docker image to Artifact Registry
* deploy to GKE
* commit version update

#### increment_version
The app's version is incremented using a custom script located in the `/scripts` directory. Saves the image name, image version, and build number as an environmental variable.
#### build and push docker image to Artifact Registry
Build the image with the specified Docker repository server, image name, image version, and build number. [Logins to the private docker repo](https://cloud.google.com/artifact-registry/docs/docker/authentication#token) using predefined Jenkins credentials Pushes the said image to a private repository.
#### deploy to GKE
A Google Compute instance needs to have the [proper scopes](https://cloud.google.com/compute/docs/access/create-enable-service-accounts-for-instances#changeserviceaccountandscopes) to be able to login to the cluster. The best practice for auth scopes is to grant a VM `cloud-platform` scope and then manage it by giving the least privileges needed through IAM roles.

You also need to configure a [docker-registry secret](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line) on the cluster so that the pods inside your cluster will be able to pull images from the private repository. So for my example, the creation of this secret will look something like this:

```shell
kubectl create secret docker-registry my-registry-key \
--docker-server=https://europe-west3-docker.pkg.dev \
--docker-username=oauth2accesstoken \
--docker-password=${gcloud auth print-access-token} \
--docker-email=vlad@samoilenko.xyz
```
The name for this secret is referenced in the helm chart in `spec.template.spec.imagePullSecrets`. It is parameterized in the `values` files, so you can change the name of the secret in the command and in the `values.yaml` file.

The stage gets the credentials for the hardcoded cluster and deploys the workload with `helmfile sync` command.
#### commit version update
Utilizes the [custom shared library](https://gitlab.com/saymolet/jenkins-shared-library.git) to login, configure, and push the version bump to the main branch.

### If you have any questions or propositions please contact me at [vlad@samoilenko.xyz](mailto:vlad@samoilenko.xyz). I will gladly answer them.

## Reference

CSS and the idea for this application came from [Angela Yu](https://github.com/angelabauer)
