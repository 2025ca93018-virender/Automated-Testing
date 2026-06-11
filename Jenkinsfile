pipeline {
    agent any

    environment {
        VENV_DIR     = 'venv'
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
                bat '''
                    python -m venv %VENV_DIR%
                    call %VENV_DIR%\\Scripts\\activate.bat
                    python -m pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Start App') {
            steps {
                powershell '''
                    $pythonExe = Join-Path $env:WORKSPACE "$env:VENV_DIR\\Scripts\\python.exe"
                    $appScript = Join-Path $env:WORKSPACE "app\\app.py"
                    $logOut    = Join-Path $env:WORKSPACE "app.log"
                    # Launch via cmd.exe using Start-Process default (ShellExecute) so the
                    # Flask child does NOT inherit Jenkins' output pipe (which would hang the step).
                    $cmdArgs = '/c ""' + $pythonExe + '" "' + $appScript + '" > "' + $logOut + '" 2>&1"'
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs `
                        -WorkingDirectory $env:WORKSPACE -WindowStyle Hidden -PassThru
                    $proc.Id | Out-File (Join-Path $env:WORKSPACE "app.pid") -Encoding ascii -NoNewline
                    $ready = $false
                    for ($i = 0; $i -lt 30; $i++) {
                        try {
                            Invoke-WebRequest -Uri http://localhost:5000/login -UseBasicParsing -ErrorAction Stop | Out-Null
                            $ready = $true
                            break
                        } catch {
                            Start-Sleep -Seconds 1
                        }
                    }
                    if (-not $ready) { throw "App did not start within 30 seconds" }
                '''
            }
        }

        stage('Run Tests') {
            steps {
                bat '''
                    call %VENV_DIR%\\Scripts\\activate.bat
                    pytest tests/test_login.py -v ^
                        --html=report.html ^
                        --self-contained-html ^
                        --junitxml=results.xml
                '''
            }
        }
    }

    post {
        always {
            powershell '''
                $pidFile = Join-Path $env:WORKSPACE "app.pid"
                if (Test-Path $pidFile) {
                    $appPid = Get-Content $pidFile
                    # Kill the whole tree (cmd.exe launcher + python child).
                    cmd /c "taskkill /PID $appPid /T /F" 2>$null
                    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
                }
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
