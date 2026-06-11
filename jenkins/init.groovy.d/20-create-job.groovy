/*
 * Runs automatically at Jenkins startup (init.groovy.d).
 * Creates/updates a Pipeline job that pulls the Jenkinsfile from this
 * repository's Git remote. Configuration comes from system properties
 * passed by setup-jenkins.ps1:
 *   -Dsetup.jobName     (default: Automated-Testing)
 *   -Dsetup.repoUrl     (required - the git remote URL)
 *   -Dsetup.repoBranch  (default: master)
 *   -Dsetup.jenkinsfile (default: Jenkinsfile)
 * Idempotent: safe to run on every boot.
 */
import jenkins.model.Jenkins
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.GitSCM
import hudson.plugins.git.UserRemoteConfig
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition

def jobName    = System.getProperty('setup.jobName', 'Automated-Testing')
def repoUrl    = System.getProperty('setup.repoUrl')
def branch     = System.getProperty('setup.repoBranch', 'master')
def scriptPath = System.getProperty('setup.jenkinsfile', 'Jenkinsfile')

if (repoUrl == null || repoUrl.trim().isEmpty()) {
    println '[init] setup.repoUrl not provided - skipping job creation.'
    return
}

def jenkins = Jenkins.instance
def job = jenkins.getItem(jobName)
if (job == null) {
    job = jenkins.createProject(WorkflowJob, jobName)
    println "[init] Created pipeline job '${jobName}'."
}

def remote = new UserRemoteConfig(repoUrl.trim(), null, null, null)
def scm = new GitSCM([remote], [new BranchSpec("*/${branch}")], null, null, [])
def flow = new CpsScmFlowDefinition(scm, scriptPath)
flow.setLightweight(true)
job.setDefinition(flow)
job.save()

println "[init] Configured '${jobName}' from ${repoUrl} (branch ${branch}, script ${scriptPath})."
