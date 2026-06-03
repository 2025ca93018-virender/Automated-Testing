pipeline {
    agent any

    environment {
        VENV_DIR    = 'venv'
        HF_API_TOKEN = credentials('HF_API_TOKEN')
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

        stage('Start App') {
            steps {
                sh '''
                    . ${VENV_DIR}/bin/activate
                    nohup python3 app/app.py > app.log 2>&1 &
                    echo $! > app.pid
                    # Wait until the app is ready
                    for i in $(seq 1 15); do
                        curl -s http://localhost:5000/login > /dev/null && break
                        sleep 1
                    done
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    . ${VENV_DIR}/bin/activate
                    pytest tests/test_login.py -v \
                        --html=report.html \
                        --self-contained-html \
                        --junitxml=results.xml
                '''
            }
        }
    }

    post {
        always {
            sh '''
                if [ -f app.pid ]; then
                    kill $(cat app.pid) || true
                    rm -f app.pid
                fi
            '''
            junit 'results.xml'
            publishHTML(target: [
                allowMissing         : false,
                alwaysLinkToLastBuild: true,
                keepAll              : true,
                reportDir            : '.',
                reportFiles          : 'report.html',
                reportName           : 'Selenium Test Report'
            ])
            archiveArtifacts artifacts: 'app.log', allowEmptyArchive: true
        }
        success {
            echo 'All tests passed!'
        }
        failure {
            echo 'Some tests failed. Check the report for details.'
        }
    }
}
