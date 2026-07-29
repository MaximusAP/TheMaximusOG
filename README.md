# TheMaximus Automated CI/CD

Flow:

GitHub → Jenkins Dynamic Docker Agent → SonarQube → Quality Gate → Docker Build → Nexus → Kubernetes → Technitium DNS → Nginx Proxy Manager → End-to-End Test

## Project defaults

- Application: `themaximus`
- Namespace: `themaximus`
- Hostname: `themaximus.lab.local`
- Nexus registry: `192.168.2.128:8082`
- Kubernetes ingress IP: `192.168.2.130`

## Required Jenkins plugins

- Pipeline
- Git
- Docker
- Docker Pipeline
- SonarQube Scanner for Jenkins
- Credentials Binding
- Workspace Cleanup

## Required Jenkins credentials

| Credential ID | Type | Purpose |
|---|---|---|
| `nexus-creds` | Username and password | Push image and create Kubernetes pull secret |
| `kubeconfig-prod` | Secret file | Kubernetes access |
| `technitium-api-token` | Secret text | Technitium DNS API |
| `npm-creds` | Username and password | Nginx Proxy Manager API login |

## Jenkins global configuration

Configure SonarQube installation name exactly as:

`SonarQube-Server`

Configure the SonarQube webhook to:

`http://<JENKINS-IP>:8080/sonarqube-webhook/`

Configure the Jenkins Docker Cloud agent label as:

`docker-slave`

The dynamic agent must have access to Docker using:

`/var/run/docker.sock:/var/run/docker.sock`

## Configuration

Edit `project.env` before the first run.

For Technitium and NPM, set the API base URLs to match your environment. The scripts are idempotent: they query first, then create or update.

## First deployment

1. Create a new GitHub repository.
2. Copy this project into it.
3. Update `project.env`.
4. Commit and push.
5. Create a Jenkins Pipeline or Multibranch Pipeline pointing to the repository.
6. Run the pipeline.

## Notes

- An IPv4 address requires an `A` record, not an `AAAA` record.
- The DNS record must point to the Nginx Proxy Manager IP.
- NPM forwards HTTP traffic to the Kubernetes ingress IP on port 80.
- NPM must preserve the original Host header so ingress routing can match `themaximus.lab.local`.

## Jenkins dynamic-agent requirement

The Docker Cloud template labeled `docker-slave` must contain these commands:

```bash
docker
kubectl
curl
git
python3
sonar-scanner
```

The template must mount `/var/run/docker.sock:/var/run/docker.sock`. The Jenkinsfile intentionally uses `agent { label 'docker-slave' }` and does not launch a nested `docker:25-cli` container.
