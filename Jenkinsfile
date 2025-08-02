pipeline{
    agent any
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
                // Add your build commands here
                mvn clean install
            }
        }
        stage('Test') {
            steps {
                echo 'Testing...'
                // Add your test commands here
                mvn test
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying...'
                // Add your deployment commands here
            }
        }
    }
}