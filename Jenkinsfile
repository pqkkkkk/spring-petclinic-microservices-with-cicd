pipeline{
    agent any
    environment {
        JAVA_HOME = tool 'JDK21'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
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
                    env.CHANGED_SERVICES = changeFiles.collect{
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

                    // 2. Get code coverage report
                    recordCoverage(
                        tools:[
                            [parser: 'JACOCO', pattern: '**/target/site/jacoco/jacoco.xml']
                        ],
                        checksAnnotationScope: 'SKIP',

                    )
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

    currentBuild.changeSets.each { changeSet ->
        changeSet.items.each { commit ->
            commit.affectedFiles.each { file ->
                changedFiles.add(file.path)
            }
        }
    }

    return changedFiles
}