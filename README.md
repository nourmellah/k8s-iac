# K3s / Vagrant / Ansible Software Factory Lab

This project builds a small Software Factory lab with 4 Vagrant/VirtualBox VMs, K3s, Ansible, Gitea, Nexus, Jenkins, NFS, a frontend, a backend, and MySQL.

The goal is to demonstrate this full workflow:

```text
Developer pushes code to Gitea
        ↓
Jenkins is triggered automatically
        ↓
Jenkins builds frontend and backend images
        ↓
Jenkins pushes both images to Nexus Docker Registry
        ↓
Jenkins deploys the new version to K3s
        ↓
Frontend calls backend, backend writes to MySQL, MySQL uses NFS storage
```

## VM architecture

| VM | IP | Functional role |
|---|---:|---|
| `worker-ci` | `192.168.56.13` | Tools VM: Gitea, Nexus, NFS, bootstrap image builds |
| `cp1` | `192.168.56.10` | K3s control-plane/master and Jenkins |
| `worker-app-1` | `192.168.56.11` | K3s worker for frontend/backend workloads |
| `worker-app-2` | `192.168.56.12` | K3s worker for frontend/backend workloads and MySQL |

`worker-ci` keeps its old VM name, but functionally it is the Tools VM. It must **not** join the K3s cluster.

Expected Kubernetes nodes:

```bash
cp1
worker-app-1
worker-app-2
```

## Service URLs

| Service | URL / endpoint | Username | Password |
|---|---|---|---|
| Jenkins | <http://192.168.56.10:30080> | `admin` | `admin123` |
| Gitea | <http://192.168.56.13:30082> | `giteaadmin` | `giteaadmin123` |
| Nexus UI | <http://192.168.56.13:30083> | `admin` | `admin123` |
| Nexus Docker Registry | `192.168.56.13:30084` | `admin` | `admin123` |
| Frontend app | <http://192.168.56.10:30081> | - | - |

## Application structure

```text
frontend/
  Dockerfile
  index.html
  nginx.conf

backend/
  Dockerfile
  app.py
  requirements.txt

kubernetes/
  frontend/
  backend/
  mysql/
  storage/
  jenkins/
  namespaces/

ci/
  Jenkinsfile
```

The frontend is an Nginx container. It exposes the UI and proxies `/api/*` requests to the backend service inside Kubernetes.

The backend is a Flask API. It connects to MySQL using:

```text
mysql.database.svc.cluster.local:3306
```

MySQL stores its data on an NFS-backed PersistentVolume exported by the Tools VM:

```text
192.168.56.13:/srv/nfs/mysql
```

## Deploy from zero

From the project root:

```bash
vagrant up
cd ansible
ansible-playbook playbooks/site.yml
```

Or use the reset/rebuild helper:

```bash
./scripts/rebuild-lab.sh
```

## Verify the lab

After provisioning:

```bash
./scripts/verify-lab.sh
```

The verification script checks:

```text
- 4 VMs reachable
- Gitea reachable on the Tools VM
- Nexus UI reachable on the Tools VM
- Nexus Docker Registry reachable on the Tools VM
- Jenkins reachable on cp1
- K3s has exactly 3 nodes
- worker-ci/tools is not part of the K3s cluster
- Jenkins pod is scheduled on cp1
- NFS export is visible from a worker
- MySQL PVC exists
- MySQL is ready
- backend deployment is ready
- frontend deployment is ready
- frontend -> backend -> MySQL path works
```

## Developer workflow demo

1. Open Gitea:

   ```text
   http://192.168.56.13:30082
   ```

2. Login with:

   ```text
   giteaadmin / giteaadmin123
   ```

3. Open the repository:

   ```text
   giteaadmin/software-factory-app
   ```

4. Edit frontend or backend code locally.

5. Push the project to the Gitea lab repository:

   ```bash
   ./scripts/push-local-repo.sh
   ```

6. Jenkins should trigger automatically through the Gitea webhook.

7. Jenkins fallback polling is also configured with:

   ```text
   H/1 * * * *
   ```

8. Open Jenkins:

   ```text
   http://192.168.56.10:30080
   ```

9. Check the job:

   ```text
   software-factory-app
   ```

10. Open Nexus and confirm that both images were pushed:

   ```text
   software-factory/frontend
   software-factory/backend
   ```

11. Open the frontend:

   ```text
   http://192.168.56.10:30081
   ```

12. Click the button to write a visit to MySQL.

## Important design decisions

### Why the Jenkinsfile is inside `ci/Jenkinsfile`

The Jenkinsfile belongs to the application repository. Jenkins does not own the pipeline source; it reads the pipeline from Gitea.

Jenkins job configuration:

```text
Repository: http://192.168.56.13:30082/giteaadmin/software-factory-app.git
Script path: ci/Jenkinsfile
Branch: main
```

### Why Gitea/Nexus/NFS are outside Kubernetes

The professor’s architecture separates the Tools VM from the Kubernetes cluster. Therefore:

```text
Gitea = Tools VM service
Nexus = Tools VM service
NFS = Tools VM service
Jenkins = Kubernetes master service
frontend/backend/database = Kubernetes workloads
```

This makes the platform easier to explain during the demo.

### Why the database runs only on `worker-app-2`

`worker-app-2` has the Kubernetes node label:

```text
storage=mysql
```

The MySQL StatefulSet uses:

```yaml
nodeSelector:
  storage: mysql
```

The database pod is scheduled on `worker-app-2`, but its storage is mounted from the Tools VM through NFS.

## Useful commands

Show K3s nodes:

```bash
vagrant ssh cp1 -c "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide"
```

Show app pods:

```bash
vagrant ssh cp1 -c "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n hello get pods -o wide"
```

Show database PVC:

```bash
vagrant ssh cp1 -c "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n database get pvc"
```

Check NFS export:

```bash
vagrant ssh worker-app-1 -c "showmount -e 192.168.56.13"
```

Check Nexus registry endpoint:

```bash
curl -i http://192.168.56.13:30084/v2/
```

A `401 Unauthorized` response is normal. It means the registry endpoint is alive and requires authentication.

## Cleanup

```bash
./scripts/reset-lab.sh
```

This removes Vagrant state and stale VirtualBox machines named:

```text
iac-k8s-cp1
iac-k8s-worker-app-1
iac-k8s-worker-app-2
iac-k8s-worker-ci
```


## Jenkins startup note

The playbook builds a custom Jenkins controller image on the Tools VM and pushes it to Nexus before installing Jenkins with Helm. This image preinstalls the required plugins (`kubernetes`, `workflow-aggregator`, `git`, `configuration-as-code`) so the Jenkins pod does not need to download plugins during init.
