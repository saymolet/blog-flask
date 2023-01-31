# Flask Blog

This Blog was build with Python using Flask. Complete with authentication, password hashing, a database, forms, comments, admin privileges for the first user, and error-handling. You can either deploy it with the help of the docker-compose file or deploy it to the Kubernetes cluster with the help of the custom Helm chart. 

## Demo


https://user-images.githubusercontent.com/101016860/215082267-2daccfbb-82a5-43ff-b7ab-9d2a8104b892.mp4


## Prerequisites

For Docker deployment:
* Docker
* Docker Compose

For Kubernetes deployment:
* Any kubernetes cluster (Managed or Local)
* Helm
* Helmfile
* Kubectl

In both setups you need to export the following environmental variables.

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

## Usage

### Docker

Build docker image of the application:

```shell
$ docker build -t flask-blog .
```

Then use the docker-compose file to bring up
three containers:
```shell
$ docker-compose -f docker-compose.yaml up
```

The application will be available at `127.0.0.1:5000`. 
The first user to register is granted admin privileges to
create, edit and delete posts from the blog. Other users
can only read and comment on posts. 

You can access the pgadmin4 at `127.0.0.1:8080`. The 
email for admin user is env variable `PG4_EMAIL`. The password 
is the env variable `PG4_PASSWORD` exported at the start.

The first time you log in to the pgadmin4 you will not see
the database just yet. Import the server by clicking 
`Tools-->Import/Export Servers...-->Upload the servers-docker.json
file located in servers-jsons folder-->Next-->Choose the server-->Next-->Finish`
Now just expand the `Servers` tab and input the password from
`DB_PASSWORD` env var.

<div align="center">
<img src="images/img.png" alt="drawing" width="700"/>
</div>

To see the data go to `Servers-->{your_db_name}-->posts-->
Schemas-->public-->Tables`. Then right click on any table and
select `View/Edit Data-->All Rows`.

Uninstall docker setup with the folowing command:
``````shell
docker-compose -f docker-compose.yaml down
``````

### Kubernetes

I've written a custom helm chart for this project. This chart will deploy Stateful Sets for pgadmin4 and PostgreSQL, Deployment for the application and all the respected Config Maps, Secrets, Services and VolumeClaims. This chart was tested locally with the help of the `minikube`, and all worked as expected.

Also, the chart was tested at a managed K8s cluster (LKE), and pgadmin was behaiving weird. It won't log in any users; it's just stuck at the log-in screen. I wasn't able to find the solution to this problem, but other than that, the application works fine.

If pgadmin works fine for you, then you just need to import the server exactly the same as in Docker deployment, just use the `servers-k8s.json` file instead.

Deploy the helm chart:
```shell
$ helmfile sync
```
Check the pods in the cluster:
```shell
$ kubectl get pods
```
Destroy and purge the deployed helm charts:
```shell
$ helmfile destroy
```
Note that the command above WILL NOT delete the PVC and PV from the cluster.

## Reference

CSS and the idea for this application came from [Angela Yu](https://github.com/angelabauer)
