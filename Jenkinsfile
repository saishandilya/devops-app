def registry = "<your jfrog-registry url>"
def imageNameJfrogArtifact = "<jfrog-docker-artifactory-name/app-name>"
def imageNameDocker = "<docker-username/app-name>"
def version   = "1.0.1"

pipeline {
    agent { node { label 'slave' } }

    parameters {
        choice(name: 'ACTION', choices: ['deploy', 'uninstall'], description: 'Choose deploy or uninstall')
    }

    environment {
        GIT_COMMIT = ""
        PATH="/opt/apache-maven-3.9.6/bin:$PATH"
        SONAR_TOKEN=credentials('sonar-token')
        SONAR_PROJECT_KEY="<your sonar project key>"
        SONAR_ORG="<your sonar organisation name>"
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
                                "pattern": "${env.WORKSPACE}/<jenkins pipeline name>/target/(*)",
                                "target": "<repository prefix name>-libs-release-local/{1}",
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