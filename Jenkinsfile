// Netflix Clone - DevSecOps CI pipeline
// Before using: replace the three values marked "CHANGE ME" below,
// and create the Jenkins tools and credentials listed in the README (Step 4).

pipeline {
    agent any

    tools {
        jdk 'jdk17'        // Manage Jenkins > Tools > JDK installations
        nodejs 'node16'    // Manage Jenkins > Tools > NodeJS installations
    }

    environment {
        SCANNER_HOME = tool 'sonar-scanner'                                          // Manage Jenkins > Tools > SonarQube Scanner
        GIT_REPO     = 'https://github.com/<your-github-username>/DevSecOps-Project.git' // CHANGE ME: your fork
        IMAGE        = '<your-dockerhub-username>/netflix'                           // CHANGE ME: your Docker Hub repo
        NOTIFY_EMAIL = 'your-email@gmail.com'                                        // CHANGE ME: where build emails go
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: "${GIT_REPO}"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''
                        $SCANNER_HOME/bin/sonar-scanner \
                          -Dsonar.projectKey=netflix \
                          -Dsonar.projectName=Netflix \
                          -Dsonar.sources=.
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                // Needs the SonarQube webhook from README Step 4.6.
                // abortPipeline: false = report the result but keep going.
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'npm install --legacy-peer-deps --no-audit'
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh 'trivy fs . > trivyfs.txt'
            }
        }

        stage('Docker Build & Push') {
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS'),
                    string(credentialsId: 'tmdb-api-key', variable: 'TMDB_KEY')
                ]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker build --build-arg TMDB_V3_API_KEY="$TMDB_KEY" -t "$IMAGE:latest" -t "$IMAGE:$BUILD_NUMBER" .
                        docker push "$IMAGE:latest"
                        docker push "$IMAGE:$BUILD_NUMBER"
                        docker logout
                    '''
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh 'trivy image "$IMAGE:latest" > trivyimage.txt'
            }
        }

        stage('Deploy to Container') {
            steps {
                // Fixed name + remove first, so each build replaces the old container
                sh 'docker rm -f netflix-app || true'
                sh 'docker run -d --name netflix-app -p 8081:80 --restart unless-stopped "$IMAGE:latest"'
            }
        }
    }

    post {
        always {
            emailext attachLog: true,
                subject: "'${currentBuild.result}' - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Project: ${env.JOB_NAME}<br/>" +
                      "Build Number: ${env.BUILD_NUMBER}<br/>" +
                      "Status: ${currentBuild.result}<br/>" +
                      "URL: ${env.BUILD_URL}<br/>",
                to: "${NOTIFY_EMAIL}",
                attachmentsPattern: 'trivyfs.txt,trivyimage.txt'
        }
    }
}
