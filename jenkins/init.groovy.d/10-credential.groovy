/*
 * Runs automatically at Jenkins startup (init.groovy.d).
 * Creates/updates the "HF_API_TOKEN" secret-text credential from the
 * HF_API_TOKEN environment variable that setup-jenkins.ps1 exports.
 * Idempotent: safe to run on every boot.
 */
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsProvider
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.Domain
import org.jenkinsci.plugins.plaincredentials.StringCredentials
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret

def token = System.getenv('HF_API_TOKEN')
if (token == null || token.trim().isEmpty()) {
    println '[init] HF_API_TOKEN env var not set - skipping credential creation.'
    return
}

def store = SystemCredentialsProvider.getInstance().getStore()
def existing = CredentialsProvider.lookupCredentials(
        StringCredentials, Jenkins.instance, null, null
).find { it.id == 'HF_API_TOKEN' }

def cred = new StringCredentialsImpl(
        CredentialsScope.GLOBAL,
        'HF_API_TOKEN',
        'Hugging Face API token',
        Secret.fromString(token.trim())
)

if (existing != null) {
    store.updateCredentials(Domain.global(), existing, cred)
    println '[init] Updated HF_API_TOKEN credential.'
} else {
    store.addCredentials(Domain.global(), cred)
    println '[init] Created HF_API_TOKEN credential.'
}
