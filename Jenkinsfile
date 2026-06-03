pipeline {
    agent any

    environment {
        VENV_DIR = 'venv'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Setup Python Environment') {
            steps {
                sh '''
                    python3 -m venv ${VENV_DIR}
                    . ${VENV_DIR}/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    . ${VENV_DIR}/bin/activate
                    pytest test_login.py -v \
                        --html=report.html \
                        --self-contained-html \
                        --junitxml=results.xml
                '''
            }
        }
    }

    post {
        always {
            junit 'results.xml'
            publishHTML(target: [
                allowMissing         : false,
                alwaysLinkToLastBuild: true,
                keepAll              : true,
                reportDir            : '.',
                reportFiles          : 'report.html',
                reportName           : 'Selenium Test Report'
            ])
        }
        success {
            echo 'All tests passed!'
        }
        failure {
            echo 'Some tests failed. Check the report for details.'
        }
    }
}
