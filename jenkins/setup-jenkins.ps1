<#
.SYNOPSIS
    One-command, reproducible local Jenkins for the Automated-Testing pipeline.

.DESCRIPTION
    Anyone who has cloned this repo can run this script to get a working Jenkins
    that builds the Jenkinsfile and produces the Selenium HTML/JUnit report.

    It will:
      1. Locate a Java 17+ runtime (required by modern Jenkins LTS).
      2. Download Jenkins LTS (jenkins.war) into .\jenkins\ if missing.
      3. Download the Jenkins Plugin Manager and install the required plugins.
      4. Drop the init.groovy.d scripts that auto-create the HF_API_TOKEN
         credential and the "Automated-Testing" pipeline job.
      5. Start Jenkins (setup wizard disabled) on http://localhost:<Port>.

    The HF_API_TOKEN is read from the environment or from the repo-root .env file.

.PARAMETER Port
    HTTP port for Jenkins. Default: 8080.

.PARAMETER JenkinsVersion
    Jenkins LTS version to download. Default: 2.555.3.

.PARAMETER RepoUrl
    Git remote URL the pipeline job checks out. Defaults to this repo's
    'origin' remote, so forks work automatically.

.PARAMETER Branch
    Branch the pipeline job builds. Default: master.

.EXAMPLE
    .\jenkins\setup-jenkins.ps1

.EXAMPLE
    .\jenkins\setup-jenkins.ps1 -Port 9090
#>
[CmdletBinding()]
param(
    [int]    $Port           = 8080,
    [string] $JenkinsVersion = '2.555.3',
    [string] $RepoUrl        = '',
    [string] $Branch         = 'master',
    [string] $PluginManagerVersion = '2.13.2'
)

$ErrorActionPreference = 'Stop'

# --- Paths -----------------------------------------------------------------
$JenkinsDir = $PSScriptRoot                                  # ...\jenkins
$RepoRoot   = Split-Path -Parent $JenkinsDir                 # repo root
$JenkinsHome = Join-Path $JenkinsDir 'home'
$WarPath     = Join-Path $JenkinsDir 'jenkins.war'
$PmJar       = Join-Path $JenkinsDir 'jenkins-plugin-manager.jar'
$PluginsTxt  = Join-Path $JenkinsDir 'plugins.txt'
$InitSource  = Join-Path $JenkinsDir 'init.groovy.d'

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# --- Build a complete PATH (System32 + PowerShell) -------------------------
# Done first so cmd/git/powershell work here, and so Jenkins child build steps
# inherit a usable PATH. Without System32 + PowerShell the pipeline's
# 'powershell' steps fail with CreateProcess error=2.
$sys     = Join-Path $env:windir 'System32'
$psDir   = Join-Path $sys 'WindowsPowerShell\v1.0'
$wbem    = Join-Path $sys 'Wbem'
$machine = [System.Environment]::ExpandEnvironmentVariables([System.Environment]::GetEnvironmentVariable('Path','Machine'))
$user    = [System.Environment]::ExpandEnvironmentVariables([System.Environment]::GetEnvironmentVariable('Path','User'))
$env:Path = "$sys;$env:windir;$psDir;$wbem;$machine;$user"

# --- 1. Locate Java 17+ ----------------------------------------------------
function Find-Java {
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += (Join-Path $env:JAVA_HOME 'bin\java.exe') }
    $candidates += 'java'
    # Common Adoptium / Microsoft install locations.
    $candidates += Get-ChildItem -Path @(
        'C:\Program Files\Eclipse Adoptium',
        'C:\Program Files\Microsoft\jdk*',
        'C:\Program Files\Java'
    ) -Filter 'java.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\bin\\java.exe$' } |
        Select-Object -ExpandProperty FullName

    foreach ($java in ($candidates | Select-Object -Unique)) {
        try {
            # Capture via ComSpec so native stderr (java -version) is read cleanly.
            $verLine = (& $env:ComSpec /c "`"$java`" -version 2>&1" | Select-Object -First 1)
            if ($verLine -match '"(\d+)(\.\d+)*') {
                $major = [int]$Matches[1]
                if ($major -ge 17) {
                    Write-Host "Using Java: $java ($verLine)"
                    return $java
                }
            }
        } catch { }
    }
    return $null
}

Write-Step 'Locating Java 17+'
$Java = Find-Java
if (-not $Java) {
    Write-Error @"
No Java 17 or newer was found. Modern Jenkins LTS requires Java 17 or 21.
Install Temurin JDK 21 from https://adoptium.net/ and re-run this script.
(After installing, open a NEW terminal so PATH/JAVA_HOME refresh.)
"@
    exit 1
}

# --- 2. Download Jenkins war ----------------------------------------------
Write-Step "Ensuring Jenkins $JenkinsVersion war is present"
New-Item -ItemType Directory -Force -Path $JenkinsHome | Out-Null
if (-not (Test-Path $WarPath)) {
    $warUrl = "https://get.jenkins.io/war-stable/$JenkinsVersion/jenkins.war"
    Write-Host "Downloading $warUrl ..."
    Invoke-WebRequest -Uri $warUrl -OutFile $WarPath
} else {
    Write-Host "Found existing $WarPath"
}

# --- 3. Install plugins ----------------------------------------------------
Write-Step 'Installing required plugins'
if (-not (Test-Path $PmJar)) {
    $pmUrl = "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$PluginManagerVersion/jenkins-plugin-manager-$PluginManagerVersion.jar"
    Write-Host "Downloading Plugin Manager $PluginManagerVersion ..."
    Invoke-WebRequest -Uri $pmUrl -OutFile $PmJar
}
$pluginDir = Join-Path $JenkinsHome 'plugins'
New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
& $Java -jar $PmJar --war $WarPath --plugin-file $PluginsTxt --plugin-download-directory $pluginDir
if ($LASTEXITCODE -ne 0) { Write-Error 'Plugin installation failed.'; exit 1 }

# --- 4. Place init.groovy.d scripts ---------------------------------------
Write-Step 'Installing auto-configuration scripts'
$initTarget = Join-Path $JenkinsHome 'init.groovy.d'
New-Item -ItemType Directory -Force -Path $initTarget | Out-Null
Copy-Item -Path (Join-Path $InitSource '*.groovy') -Destination $initTarget -Force

# --- 5. Resolve HF_API_TOKEN ----------------------------------------------
Write-Step 'Resolving HF_API_TOKEN'
if (-not $env:HF_API_TOKEN) {
    $envFile = Join-Path $RepoRoot '.env'
    if (Test-Path $envFile) {
        $line = Get-Content $envFile | Where-Object { $_ -match '^\s*HF_API_TOKEN\s*=' } | Select-Object -First 1
        if ($line) {
            $env:HF_API_TOKEN = ($line -replace '^\s*HF_API_TOKEN\s*=', '').Trim().Trim('"').Trim("'")
        }
    }
}
if ($env:HF_API_TOKEN) {
    Write-Host 'HF_API_TOKEN found (credential will be created).'
} else {
    Write-Warning 'HF_API_TOKEN not set and no .env found. The LLM test will fail until you add the credential. Create a .env with HF_API_TOKEN=... in the repo root.'
}

# --- 6. Resolve repo URL ---------------------------------------------------
if (-not $RepoUrl) {
    try {
        Push-Location $RepoRoot
        $RepoUrl = (git config --get remote.origin.url 2>$null).Trim()
    } catch { } finally { Pop-Location }
}
if (-not $RepoUrl) {
    Write-Warning 'Could not determine git remote URL. The pipeline job will not be auto-created. Pass -RepoUrl explicitly.'
}

# --- 7. Start Jenkins ------------------------------------------------------
Write-Step "Starting Jenkins on http://localhost:$Port"
Write-Host 'Once it reports "Jenkins is fully up and running":'
Write-Host "  - Open http://localhost:$Port"
Write-Host "  - Open the 'Automated-Testing' job and click 'Build Now'"
Write-Host '  - The Selenium HTML report appears under the build once it succeeds.'
Write-Host 'Press Ctrl+C in this window to stop Jenkins.'
Write-Host ''

$env:JENKINS_HOME = $JenkinsHome
$jvmArgs = @(
    '-Djenkins.install.runSetupWizard=false',
    '-Dhudson.model.UsageStatistics.disabled=true',
    "-Dsetup.repoBranch=$Branch"
)
if ($RepoUrl) { $jvmArgs += "-Dsetup.repoUrl=$RepoUrl" }

& $Java @jvmArgs -jar $WarPath --httpPort=$Port
