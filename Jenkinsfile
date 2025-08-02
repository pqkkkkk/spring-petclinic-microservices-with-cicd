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
        stage('Build'){
            steps{
                echo "Building the project..."
                sh 'mvn clean package -DskipTests'
            }
        }
        stage ('Test'){
            steps{
                echo "Running tests..."
                sh 'mvn test'
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
    } 
}