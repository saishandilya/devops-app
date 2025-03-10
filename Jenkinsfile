def registry = "https://taxibookingapp.jfrog.io/"
def imageNameJfrogArtifact = "taxi-docker-local/taxi-booking"
def imageNameDocker = "saishandilya/taxi-booking"
def dockerRegistry = "https://index.docker.io/v1/"
def containerName = imageNameDocker.split('/')[1]
def version   = "1.0.1"

pipeline {
    agent { node { label 'slave' } }

    parameters {
        choice(name: 'ACTION', choices: ['deploy', 'uninstall'], description: 'Choose deploy or uninstall')
    }

    environment {
        GIT_COMMIT = ""
        PATH                = "/opt/apache-maven-3.9.6/bin:$PATH"
        SONAR_TOKEN         = credentials('sonar-token')
        SONAR_PROJECT_KEY   = "taxiapp_taxibooking"
        SONAR_ORG           = "taxiapp"
        AWS_REGION          = "us-east-1"
        CLUSTER_NAME        = "eks-devops"
        KUBECONFIG          = "./kubeconfig"
    }


    stages {
        stage('Fetch Git Commit ID') {
            steps {
                echo 'Fetching latest Git Commit ID'
                script {
                    GIT_COMMIT = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    echo "Current Git Commit ID: ${GIT_COMMIT}"
                }
            }
        }

        stage('Compile & Build') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                echo 'Compiling and Building the application code using Apache Maven'
                sh 'mvn compile && mvn clean package'
            }
        }

        stage('Generate Test Report') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                echo "Generating test reports for the application code using Maven Surefire plugin"
                sh 'mvn test surefire-report:report'
            }
        }

        stage('Code Quality Analysis') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                echo "Performing Static Code Quality Analysis"
                sh  """
                    mvn sonar:sonar \
                        -Dsonar.organization=${SONAR_ORG} \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                        -Dsonar.host.url=https://sonarcloud.io \
                        -Dsonar.token=${SONAR_TOKEN}
                    """
            }
        }

        stage('Quality Gate Check') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                echo "Validating code quality against Bugs Quality gate metrics"
                script {
                    timeout(time: 5, unit: 'MINUTES') { // Wait for SonarCloud processing
                        sh 'sudo apt-get install -y jq || sudo yum install -y jq'
                        def status = checkSonarCloudQualityGate()
                        if (status == "ERROR") {
                            error "Quality Gate failed. Bugs exceed the threshold!"
                        } else {
                            echo "Quality Gate passed."
                        }
                    }
                }
            }
        }

        stage('Publish Artifacts To Jfrog') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                echo "Publishing Artifacts to JFrog repository"
                script {
                    // 1️⃣ Connect to JFrog Artifactory server using Jenkins Artifactory Plugin
                    def server = Artifactory.newServer(
                        url: registry + "/artifactory", 
                        credentialsId: "jfrog-token"
                    )
                    
                    // 2️⃣ Define metadata properties for tracking builds
                    def properties = "buildid=${env.BUILD_ID},commitid=${GIT_COMMIT}"
                    
                    echo "Workspace Path: ${env.WORKSPACE}"

                    // 3️⃣ Upload specification (Fixed file pattern issue)
                    def uploadSpec = """{
                        "files": [
                            {
                                "pattern": "${env.WORKSPACE}/taxi-booking-app/target/(*)",
                                "target": "taxi-libs-release-local/{1}",
                                "flat": "true",
                                "props": "${properties}"
                            }
                        ]
                    }"""

                    // 4️⃣ Upload JAR file using Artifactory plugin
                    def buildInfo = server.upload(uploadSpec)

                    // 5️⃣ Collect build environment details
                    buildInfo.env.collect()

                    // 6️⃣ Publish build information to JFrog Artifactory
                    server.publishBuildInfo(buildInfo)
                }
            }
        }

        stage('Docker Image Creation') {
            steps {
                script {
                app = docker.build(imageNameJfrogArtifact+":"+version)
                app1 = docker.build(imageNameDocker+":"+version)
                }
            }
        }

        stage('Publish Docker Image') {
            steps {
                script{
                    docker.withRegistry(registry, 'jfrog-token'){
                        app.push()
                    }
                    docker.withRegistry(dockerRegistry, 'docker-creds'){
                        app1.push()
                    }
                }
            }
        }

        stage('Create Container using Docker Image') {
            steps {
                sh """
                    echo "Container Name: ${containerName}"
                    # Check if container exists (running or stopped)
                    if [ -n "\$(docker ps -a -q -f name=^${containerName}\$)" ]; then
                        echo "Container ${containerName} is running or stopped. Removing it..."
                        docker rm -f ${containerName}
                    fi
                    echo "Running a new Container Named ${containerName}..."
                    docker run -d --name ${containerName} -p 8000:8080 ${imageNameDocker}:${version}
                    echo "New container ${containerName} is now running."
                """
            }
        }

        stage('Cluster Validation') {
            steps {
                sh """
                    CLUSTER_STATUS=\$(aws eks describe-cluster \
                        --region ${AWS_REGION} \
                        --name ${CLUSTER_NAME} \
                        --query 'cluster.status' \
                        --output text 2>/dev/null || echo "NOT_FOUND")

                    if [ "\$CLUSTER_STATUS" != "ACTIVE" ]; then
                        echo "ERROR: EKS Cluster '${CLUSTER_NAME}' is either NOT FOUND or not ACTIVE. Current Status: \$CLUSTER_STATUS"
                        exit 1
                    fi

                    echo "SUCCESS: EKS Cluster '${CLUSTER_NAME}' is: \$CLUSTER_STATUS"
                """
            }
        }

        stage('Generate Kubeconfig') {
            steps {
                sh """
                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name ${CLUSTER_NAME} \
                        --kubeconfig=${KUBECONFIG}
                """
                sh """
                    echo "Fetching the Nodes:"
                    kubectl get nodes
                """
            }
        }

        stage('Docker Creds Injection') {
            steps {
                withCredentials([string(credentialsId: 'docker-config-creds', variable: 'DOCKER_CONFIG_JSON')]) {
                sh """
                    sed -i 's|dockerconfigjson: ""|dockerconfigjson: \"$DOCKER_CONFIG_JSON\"|' ./helm-charts/values.yaml
                """
                }
            }
        }

        stage('Deploy Application using Helm') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                sh '''
                    helm upgrade --install taxi-booking ./helm-charts
                    sleep 30
                    kubectl get ns
                    kubectl get all -n taxi-app
                '''
            }
        }

        stage('Deploy Monitoring Stack using Helm') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                script {
                    def repoName = 'prometheus-community'
                    def repoUrl = 'https://prometheus-community.github.io/helm-charts'

                    def repoExists = sh(
                        script: "helm repo list | grep -w ${repoName}",
                        returnStatus: true
                    ) == 0

                    if (!repoExists) {
                        echo "Adding Helm repo: ${repoName}"
                        sh "helm repo add ${repoName} ${repoUrl}"
                    }

                    sh "helm repo update"
                    
                    // Helm install or upgrade with values.yaml
                    sh '''
                    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
                        --namespace monitoring \
                        --create-namespace \
                        -f ./helm-charts/monitoring-values.yaml
                    '''
                    echo "Monitoring stack deployed successfully!"
                    
                    sh '''
                        kubectl get ns
                        kubectl get all -n monitoring
                    '''
                }
            }
        }

        stage('Uninstall monitoring using helm') {
            when {
                expression { params.ACTION == 'uninstall' }
            }
            steps {
                script {
                    echo "Starting Helm uninstall process..."

                    // Uninstall monitoring stack
                    sh '''
                        echo "Uninstalling Monitoring stack..."
                        helm uninstall prometheus --namespace monitoring || true
                        sleep 30
                    '''

                    // Uninstall custom application
                    sh '''
                        echo "Uninstalling Application..."
                        helm uninstall taxi-booking --namespace taxi-app || true
                        sleep 30
                    '''

                    // Ensure all resources are deleted before removing namespaces
                    sh '''
                        echo "Checking if resources are fully removed..."
                        kubectl get all -n taxi-app || true
                        kubectl get all -n monitoring || true
                    '''

                    // Delete namespaces if empty
                    sh '''
                        echo "Deleting namespaces..."
                        kubectl delete ns taxi-app --ignore-not-found
                        kubectl delete ns monitoring --ignore-not-found
                    '''

                    echo "Uninstallation and cleanup completed!"
                }
            }
        }

    }
}

def checkSonarCloudQualityGate() {
    def response = sh(
        script: """
            curl -s -u ${SONAR_TOKEN}: \
            "https://sonarcloud.io/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}" \
            | jq -r '.projectStatus.status'
        """,
        returnStdout: true
    ).trim()

    return response  // "OK" if passed, "ERROR" if failed
}