#!/usr/bin/env groovy

pipeline {
    agent any

    stages {
        stage("Version Increment") {
            steps {
                script {
                    sh "poetry version minor" // you can change which version to bump (major, minor or patch)
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

        stage("Containerize") {
            steps {
                script {       
                    sh "gcloud auth configure-docker --quiet ${env.ARTIFACT_DOCKER_SERVER}"
                    sh "docker build -t ${env.ARTIFACT_DOCKER_SERVER}/${env.PROJECT_ID}/${env.ARTIFACT_NAME}/${IMAGE_NAME}:${IMAGE_VERSION} ."
                    sh "docker push ${env.ARTIFACT_DOCKER_SERVER}/${env.PROJECT_ID}/${env.ARTIFACT_NAME}/${IMAGE_NAME}:${IMAGE_VERSION} ."
                    }                   
                }
            }
        }

        stage ("Deploy to Production") {
            steps {
                script {
                    echo "Deploying to GKE"
                    // https://cloud.google.com/artifact-registry/docs/docker/authentication
                    // all of env variables are exported beforehand in jenkins global params
                    // scope set on gcloud vm to "Allow full access to all Cloud APIs". Then control it with IAM
                    // auth to cluster
                    sh "gcloud container clusters get-credentials ${env.CLUSTER_NAME} --zone ${env.CLUSTER_ZONE} --project ${env.PROJECT_ID}"
                    sh "helmfile sync"
                }
            }
        }

        stage("Version Control") {
            steps {
                script {
                    // GIT_HUB_REPO - repo url, omitting the https protocol (ending in .git)
                    // use fine-grained token instead of a password to authenticate to github
                    withCredentials([usernamePassword(credentialsId: 'github-fine-token', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                        sh "git remote set-url origin https://$USER:$PASS@${env.GIT_HUB_REPO}"
                    }
                    sh "git config user.email jenkins@jenkins.com"
                    sh "git config user.name Jenkins"
                    sh 'git add .'
                    sh "git commit -m 'ci: version bump'"
                    sh "git push origin HEAD:main"
                }
            }
        }
    }
}