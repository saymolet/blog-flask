#!/usr/bin/env groovy

pipeline {
    agent any

    environment {
        DOCKER_REPO = "europe-west3-docker.pkg.dev/exemplary-torch-377814/flask-blog"
    }    

    stages {
        stage("increment_version") {
            steps {
                script {
                    // install python3 and poetry separately on jenkins
                    // docker exec -it -u 0 {jenkins_container_id} bash
                    // apt install python3
                    // apt install python3-pip
                    // pip install poetry

                    sh "poetry version minor"
                    sh "chmod u+x ./scripts/find_name_version.sh"
                    def name = sh(script: "./scripts/find_name_version.sh 0", returnStdout: true).trim()
                    def version = sh(script: "./scripts/find_name_version.sh 1", returnStdout: true).trim()

                    env.IMAGE_NAME = "$name"
                    env.IMAGE_VERSION = "$version-$BUILD_NUMBER"
                    sh "echo $IMAGE_NAME"
                    sh "echo $IMAGE_VERSION"
                }
            }
        }

        stage("build and push docker image to Artifact Registry") {
            steps {
                script {
                    sh "docker build -t ${DOCKER_REPO}/${IMAGE_NAME}:${IMAGE_VERSION} ."
                    // gcloud init set beforehand on jenkins container 
                    // gcloud auth to Artifact Registry beforehand
                    // $ gcloud auth configure-docker europe-west3-docker.pkg.dev
                    sh "docker push ${DOCKER_REPO}/${IMAGE_NAME}:${IMAGE_VERSION}"
                }
            }
        }

        stage ("deploy to GKE") {
            steps {
                script {
                    echo "Deploying to GKE"
                    // my-registry-key secret deployed on GKE to be able to pull from private Artifact Registry on nodes
                    // https://cloud.google.com/artifact-registry/docs/docker/authentication
                    // all of env variables are exported beforehand 
                    sh "helmfile sync"
                }
            }
        }

        stage("commit version update") {
            steps {
                script {
                    // first - credentials id in Jenkins, second - where to push. Repo url, omitting the https protocol
                    // use fine-grained token instead of a password to authenticate to github
                    gitLoginRemote "github-fine-token", "github.com/saymolet/blog-flask.git"
                    // email and username for jenkins. Displayed with commit
                    gitConfig "jenkins@example.com", "jenkins"
                    // branch where to push and message with commit
                    gitAddCommitPush "main", "ci: version bump"
                }
            }
        }
    }
}