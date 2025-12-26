pipeline{
    agent any
    environment {
        JAVA_HOME = tool 'JDK21'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
        DOCKER_REGISTRY_PREFIX = "kkkkk854"
        DOCKER_CREDENTIALS_ID = 'docker-credential'
        SONAR_QUBE_ENV = 'SonarQube'
        SONAR_QUBE_CREDENTIALS_ID = 'sonar-token'
    }
    stages {
        stage('Checkout'){
            steps {
                echo 'Checking out code from SCM...'
                checkout scm
            }
        }
        stage ('Detect Change'){
            steps {
                echo 'Detecting changes in the repository...'
                script {
                    def changedFiles = getChangedFiles()
                    env.CHANGED_SERVICES = changedFiles.collect{
                        findServiceDir(it)
                    }.unique().join(',')
                }
            }
        }
        stage('Build & Test'){
            when {
                expression {
                    env.CHANGED_SERVICES?.trim()
                }
            }
            steps{
                echo 'Building and testing the application...'
                script{
                    def services = env.CHANGED_SERVICES.split(',') as List
                    def parallelBuilds = [:]

                    services.each {service ->
                        parallelBuilds[service] = {
                            dir(service){
                                echo "Building and testing service: ${service}"
                                sh 'mvn clean verify'
                            }
                        }
                    }

                    parallel parallelBuilds
                }
            }
            post{
                always{
                    // 1. Upload JUnit test results
                    junit '**/target/surefire-reports/*.xml'

                    // 2. Get code coverage report (ignore source resolution errors)
                    script {
                        try {
                            recordCoverage(
                                tools:[
                                    [parser: 'JACOCO', pattern: '**/target/site/jacoco/jacoco.xml']
                                ],
                                enabledForFailure: true
                            )
                        } catch (Exception e) {
                            echo "Coverage collection failed: ${e.message}"
                            // Continue pipeline execution
                        }
                    }
                }
            }
        }
        stage('SAST - SonarQube Analysis'){
            steps{
                echo 'Running SonarQube analysis...'
                withSonarQubeEnv(credentialsId: SONAR_QUBE_CREDENTIALS_ID, installationName: SONAR_QUBE_ENV) {
                    sh 'mvn sonar:sonar -Dsonar.projectKey=petclinic'
                }   
            }
        }
        stage('Quality Gate'){
            steps{
                echo 'Checking quality gate status...'
                timeout(time: 3, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage("Build Docker Image"){
            when {
                expression {
                    env.CHANGED_SERVICES?.trim()
                }
            }
            steps {
                echo 'Building Docker images for changed services...'
                script {
                    def services = env.CHANGED_SERVICES.split(',') as List
                    def parallelBuilds = [:]

                    services.each { service ->
                        parallelBuilds[service] = {
                            dir(service) {
                                echo "Building Docker image for service: ${service}"
                                sh "mvn clean install -DskipTest -PbuildDocker -Ddocker.image.tag=${env.GIT_COMMIT}"
                            }
                        }
                    }

                    parallel parallelBuilds
                }
            }
        }
        stage("Docker Login"){
            steps {
                script {
                    echo 'Logging into Docker registry...'
                    withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDENTIALS_ID}", usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                        sh "echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin"
                    }
                }
            }
        }
        stage("Push Docker Image"){
            when {
                expression {
                    env.CHANGED_SERVICES?.trim()
                }
            }
            steps {
                echo 'Pushing Docker images to registry...'
                script {
                    def services = env.CHANGED_SERVICES.split(',') as List
                    def parallelPushes = [:]

                    services.each { service ->
                        parallelPushes[service] = {
                            dir(service) {
                                echo "Pushing Docker image for service: ${service}"
                                sh "docker push ${env.DOCKER_REGISTRY_PREFIX}/${service}:${env.GIT_COMMIT}"
                                sh "docker tag ${env.DOCKER_REGISTRY_PREFIX}/${service}:${env.GIT_COMMIT} ${env.DOCKER_REGISTRY_PREFIX}/${service}:latest"
                                sh "docker push ${env.DOCKER_REGISTRY_PREFIX}/${service}:latest"
                            }
                        }
                    }

                    parallel parallelPushes
                }
            }
        }
    }
    post {
        success {
            echo '✅ Build and Deployment completed successfully.'
        }
        failure {
            echo '❌ Build or Deployment failed.'
        }
        always{
            githubNotify (
                context: 'CI/Build',
                status: currentBuild.currentResult,
                description: "Build #${env.BUILD_NUMBER} completed with status: ${currentBuild.currentResult}"
            )
        }
    } 
}

def findServiceDir(String filePath){
    def currentPath = filePath

    while(true){
        if(fileExists("${currentPath}/pom.xml")){
            return currentPath
        }

        int lastSlash = currentPath.lastIndexOf('/')
        if(lastSlash == -1) break

        currentPath = currentPath.substring(0, lastSlash)
    }

    if(fileExists("pom.xml")){
        return ""
    }

    return null
}

def getChangedFiles(){
    def changedFiles = []
    
    // Use git diff to compare with previous commit
    // This is more reliable than changeSets which can be empty
    try {
        def gitOutput = sh(script: 'git diff --name-only HEAD~1 HEAD', returnStdout: true).trim()
        if (gitOutput) {
            changedFiles = gitOutput.split('\n') as List
            echo "Changed files detected: ${changedFiles}"
        } else {
            echo "No changed files detected from git diff"
        }
    } catch (Exception e) {
        echo "Failed to get changed files via git diff: ${e.message}"
        echo "Falling back to changeSet method..."
        
        // Fallback to changeSets if git diff fails
        currentBuild.changeSets.each { changeSet ->
            changeSet.items.each { commit ->
                commit.affectedFiles.each { file ->
                    changedFiles.add(file.path)
                }
            }
        }
    }

    return changedFiles
}