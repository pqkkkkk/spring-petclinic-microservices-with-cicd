pipeline{
    agent any
    environment {
        JAVA_HOME = tool 'JDK21'
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
    }
    stages {
        stage ('Env Check'){
            steps {
                echo "JAVA_HOME: ${JAVA_HOME}"
                echo "PATH: ${PATH}"
            }
        }
        stage('Checkout'){
            steps {
                echo 'Checking out code from SCM...'
                checkout scm
            }
        }
        stage('Build & Test'){
            steps{
                echo 'Building and testing the application...'
                sh 'mvn clean verify'
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