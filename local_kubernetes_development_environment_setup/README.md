# Local Kubernetes development environment setup

Ce howto décrit comment préparer un environnement de développement 'Kubernetes-ready' avec un *Ingress controller* Nginx sur son poste de travail.

Il sera le point d'entrée pour les autres howtos.


## Command line tools

### Homebrew

|Lien utile|
|---|
|[Homebrew](https://brew.sh/)|

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

### kubectl

|Lien utile|
|---|
|[Install and Set Up kubectl on macOS](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/)|


    brew install kubectl
    kubectl version --client

### kubectx et kubens

|Lien utile|
|---|
|[kubectx github page](https://github.com/ahmetb/kubectx)|

    brew install kubectx


## Kubernetes en local

### Installation de Kind

    brew upgrade && brew install kind
    kind version

## Installation de Kind avec l'Ingress Controller Nginx

|Lien utile|
|---|
|[Kind Ingress](https://kind.sigs.k8s.io/docs/user/ingress/)|

### Création d'un cluster Kind avec extraPortMappings et node-labels

    cat <<EOF | kind create cluster --config=-
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
      kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
      extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
    EOF

    kind get clusters   # -> nouveau cluster nommé 'kind'


### Déploiement d'un Ingress Controller Nginx

    kubectx                         # renvoie 'kind-kind'

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml


### Test de l'Ingress 

    kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/usage.yaml

    curl localhost/foo/hostname     # renvoie 'foo-app'
    curl localhost/bar/hostname     # renvoie 'bar-app'

    # Nettoyage du test
    kubectl delete ingress example-ingress
    kubectl delete services foo-service bar-service
    kubectl delete pods foo-app bar-app


## Flux CLI install

    brew install fluxctl