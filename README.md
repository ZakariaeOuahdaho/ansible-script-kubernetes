
# 🚀 ansible-script-kubernetes

## 🚀 Déploiement Automatisé de Kubernetes avec Ansible

### 📋 Vue d'ensemble

Ce projet fournit une solution complète d'automatisation pour déployer un cluster Kubernetes multi-nœuds en utilisant Ansible. L'automatisation couvre l'installation, la configuration et l'initialisation d'un cluster Kubernetes prêt pour la production.

---

## 🏗️ Architecture Ansible

### Structure du Projet

```

ansible-script-kubernetes/
│
├── inventory.ini          # Définition des hôtes et groupes
├── playbook.yml           # Playbook principal pour Kubernetes
├── kubflow\.yml            # Playbook pour Kubeflow (exécuté depuis le master)
├── worker.yml
|---join-command.yml
└── README.md              # Documentation

```

### Workflow d'Automatisation Réel

```

┌─────────────────┐     ┌──────────────┐     ┌──────────────────┐
│ Machine Locale  │────▶│  Ansible     │────▶│ Cluster K8s Init │
│   (Ansible)     │     │  Playbook    │     │  (playbook.yml)  │
└─────────────────┘     └──────────────┘     └──────────────────┘
│
▼
┌─────────────────────────────────────┐
│      Cluster Kubernetes             │
├─────────────────────────────────────┤
│ • Master: Control Plane + Ansible  │
│ • Worker: Compute Node             │
└─────────────────────────────────────┘
│
▼
┌──────────────────┐    ┌────────────────┐    ┌─────────────────────┐
│  Master Node     │───▶│ Localhost      │───▶│ Kubeflow Deploy     │
│ (Control Plane)  │    │ Connection     │    │ (kubflow\.yml)       │
└──────────────────┘    └────────────────┘    └─────────────────────┘

````

> **Point Important** : Le playbook Kubeflow (`kubflow.yml`) est exécuté depuis le nœud master lui-même en utilisant une connexion `localhost`.

---

## 📦 Configuration de l'Inventaire

### Structure de l'Inventaire (`inventory.ini`)

```ini
[masters]
# Nœud maître - Héberge le control plane ET Ansible pour Kubeflow
zk-vmware-virtual-platform ansible_host=192.168.56.101 ansible_user=user ansible_ssh_pass=password

[workers]
# Nœud worker - Exécute les workloads
ubuntu ansible_host=192.168.56.102 ansible_user=user ansible_ssh_pass=password

[all:vars]
# Variables globales
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[localhost]
# Connexion locale DEPUIS le master pour déployer Kubeflow
localhost ansible_connection=local
````

---

## 📖 Analyse du Playbook Principal

### Structure du Playbook Kubernetes (`playbook.yml`)

Le playbook est organisé en plusieurs sections logiques :

---

### 1. Configuration Commune (Tous les Nœuds)

```yaml
- name: Configuration commune pour tous les nœuds
  hosts: all
  become: yes
  tasks:
    - name: Désactiver le swap
      command: swapoff -a

    - name: Modules kernel requis
      modprobe:
        name: "{{ item }}"
      loop:
        - overlay
        - br_netfilter
```

---

### 2. Installation des Prérequis

```yaml
    - name: Installer les dépendances
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - software-properties-common
          - gnupg2
        state: present
        update_cache: yes
```

---

### 3. Configuration du Container Runtime

```yaml
    - name: Configurer containerd
      template:
        src: daemon.json.j2
        dest: /etc/containerd/config.toml
      notify: restart containerd
```

---

### 4. Installation de Kubernetes

```yaml
    - name: Ajouter la clé GPG Kubernetes
      apt_key:
        url: https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key

    - name: Installer Kubernetes
      apt:
        name:
          - kubelet=1.29.15-*
          - kubeadm=1.29.15-*
          - kubectl=1.29.15-*
        state: present
```

---

### 5. Initialisation du Master

```yaml
- name: Initialiser le cluster Kubernetes
  hosts: masters
  tasks:
    - name: Kubeadm init
      command: >
        kubeadm init 
        --pod-network-cidr=10.244.0.0/16
        --apiserver-advertise-address={{ ansible_default_ipv4.address }}
      register: kubeadm_init
```

---

### 6. Configuration du Réseau (Flannel)

```yaml
    - name: Déployer Flannel CNI
      command: >
        kubectl apply -f 
        https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

---

### 7. Jointure des Workers

```yaml
- name: Joindre les workers au cluster
  hosts: workers
  tasks:
    - name: Rejoindre le cluster
      command: "{{ hostvars['master']['kubeadm_join_command'] }}"
```

---

### 🔧 Variables Importantes du Playbook

| Variable             | Description                  | Valeur par défaut |
| -------------------- | ---------------------------- | ----------------- |
| `kubernetes_version` | Version de K8s à installer   | `1.29.15`         |
| `pod_network_cidr`   | CIDR pour le réseau des pods | `10.244.0.0/16`   |
| `service_cidr`       | CIDR pour les services       | `10.96.0.0/12`    |
| `container_runtime`  | Runtime container            | `containerd`      |

---

## 🎯 Exécution du Déploiement

### Phase 1 : Déploiement Kubernetes

```bash
# Depuis votre machine locale
ansible-playbook -i inventory.ini playbook.yml --ask-become-pass --ask-pass
```

### Phase 2 : Déploiement Kubeflow

```bash
# Se connecter au master
ssh user@master-ip

# Cloner le projet sur le master
git clone <votre-repo>
cd ansible-script-kubernetes

# Exécuter le playbook Kubeflow DEPUIS le master
ansible-playbook -i inventory.ini kubflow.yml --ask-become-pass --ask-pass
```

---

## ✅ Résultat du Cluster Kubernetes

```
NAME                         STATUS   ROLES           AGE   VERSION
zk-vmware-virtual-platform   Ready    control-plane   26m   v1.29.15
ubuntu                       Ready    <none>          24m   v1.29.15
```

> ✅ **Cluster Kubernetes Opérationnel**

---

## 🔄 État du Déploiement Kubeflow

### Vue d'ensemble

Le déploiement Kubeflow s'initialise correctement mais rencontre des problèmes de stabilité avec certains composants, principalement liés au **stockage** et aux **dépendances entre services**.

---

### ✅ Composants Fonctionnels

```
NAMESPACE      NAME                                              STATUS    
istio-system   istio-ingressgateway-56bd64f6c4-xr7qk             1/1     Running
istio-system   istiod-5f9c6d5b9b-kqhzw                           1/1     Running
cert-manager   cert-manager-69d48d4d9b-8bfjq                     1/1     Running
cert-manager   cert-manager-cainjector-68d67b54b4-cr8rj         1/1     Running
cert-manager   cert-manager-webhook-7b8dc9db48-m8wqk            1/1     Running
auth           dex-5d8b94d7cf-hqnxm                              1/1     Running
kubeflow       ml-pipeline-ui-5688b96cbd-7ntj4                   2/2     Running
kubeflow       profiles-deployment-5f99775656-q8tkp              3/3     Running
kubeflow       training-operator-64c768746c-mg9j7                1/1     Running
```

---

### ⚠️ Composants avec Problèmes

#### 1. Pods en État Init:0/1

```
kubeflow     cache-server-54d55f7f9f-v6xk2               0/2     Init:0/1
kubeflow     centraldashboard-74974d768f-6b888           0/2     Init:0/1
kubeflow     jupyter-web-app-deployment-766756fc86-v5bjp 0/2     Init:0/1
kubeflow     katib-ui-585fb4b984-dcchd                   0/2     Init:0/1
kubeflow     metadata-grpc-deployment-d94cc8676-v9dkw    0/2     Init:0/1
kubeflow     ml-pipeline-7c44d94cfc-bv5lj                0/2     Init:0/1
kubeflow     mysql-69f7f56fdc-n5g5f                      0/2     Init:0/1
kubeflow     volumes-web-app-deployment-6d4767b875-d8k5w 0/2     Init:0/1
kubeflow     workflow-controller-5f8c886bd6-gcg7z        0/2     Init:0/1
```

**Cause principale** : Attente d’injection du sidecar Istio ou de dépendances non prêtes.

#### 2. Pods en Pending (Stockage)

```
kubeflow     katib-mysql-76b79df5b5-r9qmr                0/1     Pending
kubeflow     minio-5dc6ff5b96-6v2bz                      0/2     Pending
```

**Cause** : Absence de PVC provisionné. `StorageClass` non configuré ou défaillant.

#### 3. Pods en ContainerCreating

```
kubeflow     katib-db-manager-6bfdd64d6d-zk4bb           
kubeflow     kserve-controller-manager-858888d974-gw77q  
kubeflow     kubeflow-pipelines-profile-controller        
kubeflow     metacontroller-0                             
kubeflow     metadata-envoy-deployment-5f67cbf6c5-wklsb  
```

**Cause** : Attente de téléchargement d’images ou de volumes.

---

### 🧪 Diagnostic des Problèmes

#### 1. Problème de Stockage

```bash
kubectl get pvc -A
```

```
NAMESPACE    NAME              STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
kubeflow     katib-mysql       Pending                                      local-path     18m
kubeflow     minio-pvc         Pending                                      local-path     21m
kubeflow     mysql-pv-claim    Pending                                      local-path     21m
```

#### 2. Dépendances Istio

```bash
kubectl get namespace kubeflow -o jsonpath='{.metadata.labels}'
```

> Devrait retourner : `istio-injection=enabled`

#### 3. Erreurs de Webhook

```
Internal error occurred: failed calling webhook "clusterservingruntime.kserve-webhook-server.validator"
```

---

## 🛠️ Solutions en Cours

* 🗃️ **Stockage** : Migration vers `hostPath` ou provisioner plus simple
* ♻️ **Istio** : Redémarrage des pods après stabilisation
* 🕒 **Webhooks** : Installation séquentielle avec délais

---

## 🌐 Accès à Kubeflow (Partiel)

```bash
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
```

* Accès via navigateur : [http://localhost:8080](http://localhost:8080)
* Credentials : `admin@kubeflow.org / 12341234`

---

## 🧭 Prochaines Étapes

* ✅ Résoudre les problèmes de stockage
* 🔁 Stabiliser les dépendances
* 📄 Documenter les contournements
* ⚙️ Créer des scripts de récupération automatique

---

## 📝 Notes pour les Contributeurs

* 🔁 Reproduire l'environnement : 2 VMs Ubuntu, 4GB RAM chacune
* 📦 Suivre le workflow exact : `playbook.yml`, puis `kubflow.yml` depuis le master
* 📋 Capturer les logs : `kubectl logs -n kubeflow <pod-name> -c istio-proxy`
* 🙌 Proposer des solutions via Pull Requests

> **Note** : Ce projet est fonctionnel pour Kubernetes mais nécessite encore du travail pour stabiliser complètement Kubeflow. Les contributions sont les bienvenues !
