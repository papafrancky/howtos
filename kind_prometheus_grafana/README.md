# Minicube - prometheus - Grafana



|Description|URL|
|---:|:---|
|Install Docker Desktop on Mac|https://docs.docker.com/desktop/install/mac-install/|
|Minikube installation|https://kubernetes.io/fr/docs/tasks/tools/install-minikube/|
|Kind install|https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries|
| Helm installation|https://helm.sh/docs/intro/install/|
|Kubectl installation|https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/|
|kubens & kubectx installation|https://github.com/ahmetb/kubectx#manual-installation-macos-and-linux|
|Medium | Setup Prometheus and Grafana monitoring on Kubernetes cluster using Helm|https://medium.com/globant/setup-prometheus-and-grafana-monitoring-on-kubernetes-cluster-using-helm-3484efd85891|
|Blog - Introduction à Helm|https://blog.stephane-robert.info/post/kubernetes-introduction-helm/|

## Prerequisites


### 'Kind' installation and cluster creation

#### Linux
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube
    sudo mkdir -p /usr/local/bin/
    sudo install minikube /usr/local/bin/

    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind

#### Mac
    brew install minikube

#### Both Linux & Mac
    minikube start
    minikube status
    minikube addons enable ingress
    minikube addons list

    # resolution DNS
    minikube ip # -> 192.168.49.2
    sudo printf "# Helm training\n127.0.0.1\tfrontend.minikube.local\tbackend.minikube.local\n" >> /etc/hosts
    # For MAC OS users, we will need to make use of : minikube tunnel


### Helm installation

#### Linux
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    helm version

#### Mac
    brew install helm
    helm version


### kubectl installation

#### Linux
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    kubectl version
    printf "\nalias k=kubectl\n" >> ~/.bashrc && source ~/.bashrc
    k get po -A

#### Mac
    brew install kubectl
    kubectl version --client


### kubens and kubectx installation

#### Linux
    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
    sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

#### Mac
    brew install kubectx




## Installation of Prometheus and Grafana

### Adding Helm repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts

    helm repo list
    # NAME                	URL
    # prometheus-community	https://prometheus-community.github.io/helm-charts
    # grafana             	https://grafana.github.io/helm-charts

    helm repo update
    # Hang tight while we grab the latest from your chart repositories...
    # ...Successfully got an update from the "grafana" chart repository
    # ...Successfully got an update from the "prometheus-community" chart repository
    # Update Complete. ⎈Happy Helming!⎈



### Installing Prometheus


#### Installing the server

    helm install prometheus prometheus-community/prometheus
    
    # NAME: prometheus
    # LAST DEPLOYED: Sat Dec  9 13:26:23 2023
    # NAMESPACE: default
    # STATUS: deployed
    # REVISION: 1
    # TEST SUITE: None
    # NOTES:
    # The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
    # prometheus-server.default.svc.cluster.local
    # 
    # 
    # Get the Prometheus server URL by running these commands in the same shell:
    #   export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
    #   kubectl --namespace default port-forward $POD_NAME 9090
    # 
    # 
    # The Prometheus alertmanager can be accessed via port 9093 on the following DNS name # from within your cluster:
    # prometheus-alertmanager.default.svc.cluster.local
    # 
    # 
    # Get the Alertmanager URL by running these commands in the same shell:
    #   export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
    #   kubectl --namespace default port-forward $POD_NAME 9093
    # #################################################################################
    # ######   WARNING: Pod Security Policy has been disabled by default since    #####
    # ######            it deprecated after k8s 1.25+. use                        #####
    # ######            (index .Values "prometheus-node-exporter" "rbac"          #####
    # ###### .          "pspEnabled") with (index .Values                         #####
    # ######            "prometheus-node-exporter" "rbac" "pspAnnotations")       #####
    # ######            in case you still need it.                                #####
    # #################################################################################
    # 
    # 
    # The Prometheus PushGateway can be accessed via port 9091 on the following DNS name # from within your cluster:
    # prometheus-prometheus-pushgateway.default.svc.cluster.local
    # 
    # 
    # Get the PushGateway URL by running these commands in the same shell:
    #   export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
    #   kubectl --namespace default port-forward $POD_NAME 9091
    # 
    # For more information on running Prometheus, visit:
    # https://prometheus.io/


#### Checking installation

    kubectl get all

    # NAME                                                     READY   STATUS    RESTARTS   AGE
    # pod/prometheus-alertmanager-0                            1/1     Running   0          9m44s
    # pod/prometheus-kube-state-metrics-85596bfdb6-6r4pp       1/1     Running   0          9m44s
    # pod/prometheus-prometheus-node-exporter-w5skp            1/1     Running   0          9m44s
    # pod/prometheus-prometheus-pushgateway-79745d4495-dh8cv   1/1     Running   0          9m44s
    # pod/prometheus-server-fd677cd4c-5sc5x                    2/2     Running   0          9m44s
    # 
    # NAME                                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
    # service/kubernetes                            ClusterIP   10.96.0.1       <none>        443/TCP    44m
    # service/prometheus-alertmanager               ClusterIP   10.96.135.67    <none>        9093/TCP   9m44s
    # service/prometheus-alertmanager-headless      ClusterIP   None            <none>        9093/TCP   9m44s
    # service/prometheus-kube-state-metrics         ClusterIP   10.96.78.11     <none>        8080/TCP   9m44s
    # service/prometheus-prometheus-node-exporter   ClusterIP   10.96.170.181   <none>        9100/TCP   9m44s
    # service/prometheus-prometheus-pushgateway     ClusterIP   10.96.148.56    <none>        9091/TCP   9m44s
    # service/prometheus-server                     ClusterIP   10.96.118.59    <none>        80/TCP     9m44s
    #
    # NAME                                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
    # daemonset.apps/prometheus-prometheus-node-exporter   1         1         1       1            1           kubernetes.io/os=linux   9m44s
    #
    # NAME                                                READY   UP-TO-DATE   AVAILABLE   AGE
    # deployment.apps/prometheus-kube-state-metrics       1/1     1            1           9m44s
    # deployment.apps/prometheus-prometheus-pushgateway   1/1     1            1           9m44s
    # deployment.apps/prometheus-server                   1/1     1            1           9m44s
    #
    # NAME                                                           DESIRED   CURRENT   READY   AGE
    # replicaset.apps/prometheus-kube-state-metrics-85596bfdb6       1         1         1       9m44s
    # replicaset.apps/prometheus-prometheus-pushgateway-79745d4495   1         1         1       9m44s
    # replicaset.apps/prometheus-server-fd677cd4c                    1         1         1       9m44s
    #
    # NAME                                       READY   AGE
    # statefulset.apps/prometheus-alertmanager   1/1     9m44s


#### Port-forwarding
Prometheus port-forwarding on port 9090

    export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
    kubectl --namespace default port-forward $POD_NAME 9090 &

-> you can now access Prometheus with your browser on URL http://localhost:9090 !



### Intstalling Grafana

#### Installing Grafana

    helm install grafana grafana/grafana

    # NAME: grafana
    # LAST DEPLOYED: Sat Dec  9 14:46:26 2023
    # NAMESPACE: default
    # STATUS: deployed
    # REVISION: 1
    # NOTES:
    # 1. Get your 'admin' user password by running:
    # 
    #    kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
    # 
    # 
    # 2. The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:
    # 
    #    grafana.default.svc.cluster.local
    # 
    #    Get the Grafana URL to visit by running these commands in the same shell:
    #      export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
    #      kubectl --namespace default port-forward $POD_NAME 3000
    # 
    # 3. Login with the password from step 1 and the username: admin
    # #################################################################################
    # ######   WARNING: Persistence is disabled!!! You will lose your data when   #####
    # ######            the Grafana pod is terminated.                            #####
    # #################################################################################


#### Grafana port-forwarding
Grafana port-forwarding on port 3000

    export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
    kubectl --namespace default port-forward $POD_NAME 3000 &

-> you can now access Grafana with your browser on URL http://localhost:3000 !

To get admin password : 
    kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo 


#### Configuring Prometheus Data Source
Use the prometheus endpoints

    echo "http://$( kubectl get endpoints | grep ^prometheus-server | awk '{print $2}' )"

    # AletManager port-forwarding on port 9093
    export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=alertmanager,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
    kubectl --namespace default port-forward $POD_NAME 9093

-> you can now access Alert Manager with your browser on URL http://localhost:9093



# WORK IN PROGRESS


    helm show chart prometheus-community/prometheus
    
    # annotations:
    #   artifacthub.io/license: Apache-2.0
    #   artifacthub.io/links: |
    #     - name: Chart Source
    #       url: https://github.com/prometheus-community/helm-charts
    #     - name: Upstream Project
    #       url: https://github.com/prometheus/prometheus
    # apiVersion: v2
    # appVersion: v2.48.0
    # dependencies:
    # - condition: alertmanager.enabled
    #   name: alertmanager
    #   repository: https://prometheus-community.github.io/helm-charts
    #   version: 1.7.*
    # - condition: kube-state-metrics.enabled
    #   name: kube-state-metrics
    #   repository: https://prometheus-community.github.io/helm-charts
    #   version: 5.15.*
    # - condition: prometheus-node-exporter.enabled
    #   name: prometheus-node-exporter
    #   repository: https://prometheus-community.github.io/helm-charts
    #   version: 4.24.*
    # - condition: prometheus-pushgateway.enabled
    #   name: prometheus-pushgateway
    #   repository: https://prometheus-community.github.io/helm-charts
    #   version: 2.4.*
    # description: Prometheus is a monitoring system and time series database.
    # home: https://prometheus.io/
    # icon: https://raw.githubusercontent.com/prometheus/prometheus.github.io/master/assets/prometheus_logo-cb55bb5c346.png
    # keywords:
    # - monitoring
    # - prometheus
    # kubeVersion: '>=1.19.0-0'
    # maintainers:
    # - email: gianrubio@gmail.com
    #   name: gianrubio
    # - email: zanhsieh@gmail.com
    #   name: zanhsieh
    # - email: miroslav.hadzhiev@gmail.com
    #   name: Xtigyro
    # - email: naseem@transit.app
    #   name: naseemkullah
    # - email: rootsandtrees@posteo.de
    #   name: zeritti
    # name: prometheus
    # sources:
    # - https://github.com/prometheus/alertmanager
    # - https://github.com/prometheus/prometheus
    # - https://github.com/prometheus/pushgateway
    # - https://github.com/prometheus/node_exporter
    # - https://github.com/kubernetes/kube-state-metrics
    # type: application
    # version: 25.8.1

    # To unsinstall Prometheus
    helm uninstall prometheus

    # To get the default helm configuration :
    helm show values prometheus-community/prometheus > helm_values.prometheus.yaml.ORIG
    cp helm_values.prometheus.yaml.ORIG helm_values.prometheus.yaml

    # To install Prometheus with the default configuration :
    helm install prometheus prometheus-community/prometheus

    # To install Prometheus with a custom configuration :
    helm install prometheus prometheus-community/prometheus -f helm_values.prometheus.yaml

    # To upgrade an already installed Prometheus with a custom configuration :
    helm upgrade prometheus prometheus-community/prometheus -f helm_values.prometheus.yaml


    helm history prometheus                                                                                               1 ✘    kind-sandbox ⎈  16:47:23 
    # REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION
    # 1       	Sat Dec  9 16:34:59 2023	superseded	prometheus-25.8.1	v2.48.0    	Install complete
    # 2       	Sat Dec  9 16:46:39 2023	deployed  	prometheus-25.8.1	v2.48.0    	Upgrade complete

    helm rollback prometheus 1

## Customiser un Helm Chart à partir des fichiers source

### Chart download locally

    helm pull prometheus-community/prometheus --untar

### Install a Chart from local files

    helm install prometheus --dry-run ./prometheus -f helm_values.prometheus.yaml

### blah blah blah
k exec -it prometheus-server-fd677cd4c-7t8b8 -- sh
ps
/bin/prometheus-config-reloader --watched-dir=/etc/config --reload-url=http://127.0.0.1:9090/-/reload



## Cours Helm sur Pluralsight




### Pour tester les helms :

    helm template [chart] (works 'offline', without kubernetes)
    helm install [release] [chart] --dry-run --debug 2>&1       (real helm install but without commit)
    helm get all [release] -> compiles all the values
