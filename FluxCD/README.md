
|Topic|URL|
|---|---|

|Kind install|https://kind.sigs.k8s.io/docs/user/quick-start|
|Flux install|https://fluxcd.io/flux/installation/|
|Flux alerts|https://fluxcd.io/flux/monitoring/alerts/|
|Flux - notification controller - discord provider|https://fluxcd.io/flux/components/notification/providers/#discord|
|FluxCD - image policies - filter tags|https://fluxcd.io/flux/components/image/imagepolicies/#filter-tags|
|FluxCD - Guides - Automate image updates to Git|https://fluxcd.io/flux/guides/image-update/|
|Force FluxCD reconciliation|flux reconcile kustomization flux-system --with-source|
|Medium - How to make ahs share your own Helm package|https://medium.com/containerum/how-to-make-and-share-your-own-helm-package-50ae40f6c221|
|GitHub Pages|https://pages.github.com/|
|OCI repositories|https://fluxcd.io/flux/components/source/ocirepositories/|


# Pre-requisites

## Kind install

    brew upgrade && brew install kind
    kind version
    kind create cluster
    kins get clusters

    curl -s https://fluxcd.io/install.sh | sudo bash

GitHub repositories :
- https://github.com/papaFrancky/gitops
- https://github.com/papaFrancky/gitops-deployments



    flux check --pre

    PAT, full repo access
    export GITHUB_USER=papaFrancky
    export GITHUB_TOKEN=$( cat ~/secrets/github.papaFrancky.PAT.FluxCD.txt )

    flux bootstrap github \
      --token-auth \
      --owner ${GITHUB_USER} \
      --repository gitops \
      --branch=main \
      --path=clusters/sandbox \
      --personal \
      --components-extra=image-reflector-controller,image-automation-controller

-> https://github.com/papaFrancky/gitops/tree/main/clusters/sandbox/flux-system

    k -n flux-system get all


## Alerting (Slack)

    cd code/github
    git clone git@github.com:papaFrancky/gitops.git
    cd gitops/clusters/sandbox
    mkdir -p notifications/{providers,alerts}

WEBHOOK=https://discordapp.com/api/webhooks/1188877273575731341/Vu4g0fSMjV6pVW7m83TnQ3LWNm9uvSp5HuTF9LPuzM3yQfKX7UEgJ8YAM-6WcctcEwVm
echo -n "${WEBHOOK}" >${HOME}/secrets/discord.gitops.webhook.txt
    k create secret generic discord-gitops --from-file=address=${HOME}/secrets/discord.gitops.webhook.txt

    flux create alert-provider discord-gitops \
>     --type=discord \
>     --secret-ref=discord-gitops \
>     --channel=gitops \
>     --username=FluxCD \
>     --namespace=default \
>     --export > notifications/providers/discord-gitops-provider.yaml

cat notifications/providers/discord-gitops-provider.yaml
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: discord-gitops
  namespace: default
spec:
  channel: gitops
  secretRef:
    name: discord-gitops
  type: discord
  username: FluxCD


flux create alert discord-gitops-alert \
  --event-severity=info \
  --event-source='GitRepository/*,Kustomization/*' \
  --provider-ref=discord-gitops \
  --namespace=default \
  --export > notifications/alerts/discord-gitops-alert.yaml

cat notifications/alerts/discord-gitops-alert.yaml

---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: discord-gitops-alert
  namespace: default
spec:
  eventSeverity: info
  eventSources:
  - kind: GitRepository
    name: '*'
  - kind: Kustomization
    name: '*'
  providerRef:
    name: discord-gitops


    # cd notifications
    # kustomize create --autodetect --recursive

    cd ..
    git st && git add notifications
    git commit -m 'feat: discord alerting'
    git push

k get providers,alerts -n default
NAME                                                     AGE
provider.notification.toolkit.fluxcd.io/discord-gitops   32m

NAME                                                        AGE
alert.notification.toolkit.fluxcd.io/discord-gitops-alert   29s



    flux create secret git gitops-deployments-auth \
      --url=ssh://github.com/papaFrancky/gitops-deployments \
      --namespace=default

✚ deploy key: ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBEww+J8GaJDlxQHeB6M+qrWyn3hcv2Jj8IS5gC+O6kQOvu2hKr0iqaduoottECNXEgRbdEqABzY8gZ9Xb77e5wfskVUOqKfdiv12/CVbLFj1eH1WFlUH+Vy7Wff0I0JEAw==

► git secret 'gitops-deployments-auth' created in 'default' namespace

-> ajouter la clé publique (deploy key) dans https://github.com/papaFrancky/gitops-deployments/settings/keys/new (nom: gitops) et cocher 'Allow write access'

git clone git@github.com:papaFrancky/gitops-deployments.git


cd ${HOME}/code/github/gitops/clusters/sandbox
mkdir -p {sources,kustomizations}
flux create source git nginxhello \
  --url=ssh://github.com/papaFrancky/gitops-deployments \
  --branch=main \
  --secret-ref=gitops-deployments-auth \
  --namespace=default \
  --export > sources/nginxhello-source.yaml

cat sources/nginxhello-source.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: nginxhello
  namespace: default
spec:
  interval: 1m0s
  ref:
    branch: main
  secretRef:
    name: gitops-deployments-auth
  url: ssh://github.com/papaFrancky/gitops-deployments


flux create kustomization nginxhello \
  --source=GitRepository/nginxhello.default \
  --path=./nginxhello \
  --prune=true \
  --target-namespace=default \
  --namespace=default \
  --export > kustomizations/nginxhello-kustomization.yaml

cat kustomizations/nginxhello-kustomization.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: nginxhello
  namespace: default
spec:
  interval: 1m0s
  path: ./nginxhello
  prune: true
  sourceRef:
    kind: GitRepository
    name: nginxhello
    namespace: default
  targetNamespace: default

git add sources kustomizations
git push

 k get GitRepositories -n default
NAME         URL                                               AGE     READY   STATUS
nginxhello   ssh://github.com/papaFrancky/gitops-deployments   2m14s   False   git repository is empty

k get kustomizations -n default
NAME         AGE    READY   STATUS
nginxhello   3m1s   False   Source artifact not found, retrying in 30s


Copie de la petite appli de démo : 
https://github.com/nbrownuk/gitops-nginxhello/
-> on copie deployment.yaml et service.yaml dans ${HOME}/gitops/deployments/nginxhello (le répertoire sera créé à l'occasion)
-> git commit, git push

Le statut du GitRepo change : 


k get GitRepositories
NAME         URL                                               AGE   READY   STATUS
nginxhello   ssh://github.com/papaFrancky/gitops-deployments   26m   True    stored artifact for revision 'main@sha1:b223021b6ff0fee832941e0825a6203e4775196c'

 k get kustomizations
NAME         AGE   READY   STATUS
nginxhello   28h   True    Applied revision: main@sha1:3a1755be8df43fc45bb467490aa0adc52117a4e7

k get services
k port-forward service/nginxhello 8080:80
-> browser http://localhost:8080 -> page de nginxhello


Test : 
vi ${HOME}code/github/gitops-deployments/nginxhello/deployment.yaml
-> changer :
  .spec.replicas 2 -> 4
  .spec.template.spec.containers[0].image nbrown/nginxhello:1.19.0 -> nbrown/nginxhello:1.24.0

git commit && git push

-> k get po -w (pour regarder les changements opérer)
-> k get GitRepositories -> STATUS contient le SHA1 du commit Git (cf. git logs)
-> 2 alertes reçues par Discord dans le channel #GitOps
-> k port-forward service/nginxhello 8080:80 -> browser http://localhost:8080 -> version: 1.24.0



### Handling application updates with image automation

cd ${HOME}/code/github/gitops/clusters/sandbox
flux create image repository nginxhello \
  --image=hub.docker.com/nbrown/nginxhello \
  --interval=5m \
  --namespace=default \
  --export > sources/nginxhello-imagerepository.yaml

cat sources/nginxhello-imagerepository.yaml
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: nginxhello
  namespace: default
spec:
  image: hub.docker.com/nbrown/nginxhello
  interval: 5m0s


git add .
git commit -m 'feat: added nginxhello image repository manifest.' 
git push

git get imagerepositories

### Modification de l'alerte Discord pour prise en compte des image policies :

cd ${HOME}/code/github/gitops/clusters/sandbox
vi notifications/alerts/discord-gitops-alert.yaml
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: discord-gitops-alert
  namespace: default
spec:
  eventSeverity: info
  eventSources:
  - kind: GitRepository
    name: '*'
  - kind: Kustomization
    name: '*'
  - kind: ImagePolicy
    name: '*'
  providerRef:
    name: discord-gitops

mkdir imagepolicies
flux create image policy nginxhello \
  --image-ref=nginxhello \
  --select-semver='>=1.20.x' \
  --namespace=default \
  --export > imagepolicies/nginxhello-image-policy.yaml

cat imagepolicies/nginxhello-image-policy.yaml
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: nginxhello
  namespace: default
spec:
  imageRepositoryRef:
    name: nginxhello
  policy:
    semver:
      range: '>=1.20.x'

git commit && git push

 k get imagepolicies
NAME         LATESTIMAGE
nginxhello


k describe imagerepository nginxhello -> 
Name:         nginxhello
Namespace:    default
Labels:       kustomize.toolkit.fluxcd.io/name=flux-system
              kustomize.toolkit.fluxcd.io/namespace=flux-system
Annotations:  <none>
API Version:  image.toolkit.fluxcd.io/v1beta2
Kind:         ImageRepository
Metadata:
  Creation Timestamp:  2023-12-29T17:27:59Z
  Finalizers:
    finalizers.fluxcd.io
  Generation:        2
  Resource Version:  47347
  UID:               0eaf8380-5fad-4458-aca0-826f02d74abc
Spec:
  Exclusion List:
    ^.*\.sig$
  Image:     docker.io/nbrown/nginxhello
  Interval:  5m0s
  Provider:  generic
Status:
  Canonical Image Name:  index.docker.io/nbrown/nginxhello
  Conditions:
    Last Transition Time:  2023-12-29T18:16:39Z
    Message:               successful scan: found 45 tags
    Observed Generation:   2
    Reason:                Succeeded
    Status:                True
    Type:                  Ready
  Last Scan Result:
    Latest Tags:
      stable
      mainline
      latest
      e6c463e6
      aad042cb
      1.25.2
      1.25
      1.24.0
      1.24
      1.23.3
    Scan Time:  2023-12-29T18:16:39Z
    Tag Count:  45
  Observed Exclusion List:
    ^.*\.sig$
  Observed Generation:  2
Events:
(...)

-> Discord : 
imagepolicy/nginxhello.default
Latest image tag for 'docker.io/nbrown/nginxhello' resolved to 1.25.2

-> k get imagepolicies
NAME         LATESTIMAGE
nginxhello   docker.io/nbrown/nginxhello:1.25.2

-> k get deployment nginxhello -o yaml | yq '.spec.template.spec.containers[].image'
nbrown/nginxhello:1.20.1    # la version déployée n'est pas la dernière 


### Updating a application version with the image automation

#### Adding a marker to the deployment
cd ${HOME}/code/github/gitops-deployments
vi ${HOME}/code/github/gitops-deployments/nginxhello/deployment.yaml

git add && git commit && git push

-> git log
commit ed03554ba51d9f1e29f38711d667efebd3c9e33c (HEAD -> main, origin/main)
Author: Franck Levesque <franck.levesque@gmail.com>
Date:   Sat Dec 30 13:29:46 2023 +0100

    evol: added maker to the deployment manifest

-> k get gitrepository nginxhello
Énumération des objets: 7, fait.
Décompte des objets: 100% (7/7), fait.
Compression par delta en utilisant jusqu'à 16 fils d'exécution
Compression des objets: 100% (3/3), fait.
Écriture des objets: 100% (4/4), 432 octets | 432.00 Kio/s, fait.
Total 4 (delta 1), réutilisés 0 (delta 0), réutilisés du pack 0
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
To github.com:papaFrancky/gitops-deployments.git
   9eb887b..ed03554  main -> main

-> k get gitrepositories nginxhello
NAME         URL                                               AGE     READY   STATUS
nginxhello   ssh://github.com/papaFrancky/gitops-deployments   2d18h   True    stored artifact for revision 'main@sha1:ed03554ba51d9f1e29f38711d667efebd3c9e33c'

-> Discord message
FluxCD BOT
 — Aujourd’hui à 13:31
gitrepository/nginxhello.default
stored artifact for commit 'evol: added maker to the deployment manifest'
revision
main@sha1:ed03554ba51d9f1e29f38711d667efebd3c9e33c


#### Image update automation
cd ${HOME}/code/github/gitops/clusters/sandbox
mkdir imageupdateautomations
vi imageupdateautomations/msg_template

Flux automated image update

Automation name: {{ .AutomationObject }}

Files:
{{ range $filename, $_ := .Updated.Files -}}
- {{ $filename }}
{{ end -}}

Objects:
{{ range $resource, $_ := .Updated.Objects -}}
- {{ $resource.Kind }} {{ $resource.Name }}
{{ end -}}

Images:
{{ range .Updated.Images -}}
- {{.}}
{{ end -}}



flux create image update nginxhello \
  --git-repo-ref=nginxhello \
  --git-repo-path=./nginxhello \
  --checkout-branch=main \
  --push-branch=main \
  --author-name=FluxCD \
  --author-email=gitops@users.noreply.github.com \
  --commit-template="$( cat ${HOME}/code/github/gitops/clusters/sandbox/imageupdateautomations/msg_template )" \
  --namespace=default \
  --export > ${HOME}/code/github/gitops/clusters/sandbox/imageupdateautomations/nginxhello.yaml

cat ${HOME}/code/github/gitops/clusters/sandbox/imageupdateautomations/nginxhello.yaml

---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: nginxhello
  namespace: default
spec:
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: gitops@users.noreply.github.com
        name: FluxCD
      messageTemplate: |-
        Flux automated image update

        Automation name: {{ .AutomationObject }}

        Files:
        {{ range $filename, $_ := .Updated.Files -}}
        - {{ $filename }}
        {{ end -}}

        Objects:
        {{ range $resource, $_ := .Updated.Objects -}}
        - {{ $resource.Kind }} {{ $resource.Name }}
        {{ end -}}

        Images:
        {{ range .Updated.Images -}}
        - {{.}}
        {{ end -}}
    push:
      branch: main
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: gitops-deployments
  update:
    path: ./nginxhello
    strategy: Setters


git add && git commit && git push

-> k get pods -w
-> k get imageupdateautomations

-> k get deployment nginxhello -o yaml | yq '.spec.template.spec.containers[].image'
nbrown/nginxhello:1.20.1

cd ${HOME}/code/github/gitops-deployments
git fetch -> commit en retard
git pull
git log -1 -> message de commit correspondant à notre template

cat ${HOME}/code/github/gitops-deployments/nginxhello/deployment.yaml| grep 'image:'
      - image: docker.io/nbrown/nginxhello:1.25.2 # {"$imagepolicy": "default:nginxhello"}
-> nouvelle version : 1.25.2 (la plus récente sur le repo Docker)

-> k describe imageupdateautomations nginxhello
On retrouve dans les logs le pattern du template :
Flux automated image update

Automation name: default/nginxhello

Files:
- deployment.yaml
Objects:
- Deployment nginxhello


Images:
- docker.io/nbrown/nginxhello:1.25.2



### Automating packages releases with the Helm controller

#### Nettoyage 

cd ${HOME}/code/github/gitops/clusters/sandbox
mkdir _backup
tar cvzf _backup/imagepolicies.tgz imagepolicies
tar cvzf _backup/imageupdateautomations.tgz imageupdateautomations
tar cvzf _backup/kustomizations.tgz kustomizations 
tar cvzf _backup/sources_nginxhello-imagerepository.yaml.tgz sources/nginxhello-imagerepository.yaml
rm -rf image* kustomizations sources/nginxhello-imagerepository.yaml
 tree                                                                     ✔  16:00:24  
.
├── _backup
│   ├── imagepolicies.tgz
│   ├── imageupdateautomations.tgz
│   ├── kustomizations.tgz
│   └── sources_nginxhello-imagerepository.yaml.tgz
├── flux-system
│   ├── gotk-components.yaml
│   ├── gotk-sync.yaml
│   └── kustomization.yaml
├── notifications
│   ├── alerts
│   │   └── discord-gitops-alert.yaml
│   └── providers
│       └── discord-gitops-provider.yaml
└── sources
    └── nginxhello-source.yaml

git add && git commit && git push

-> Discord :
FluxCD BOT
 — Aujourd’hui à 16:04
kustomization/nginxhello.default
Deployment/default/nginxhello deleted
Service/default/nginxhello deleted
revision
main@sha1:5855cb796a4e1b7cd07d3c9da8351debb0dff3f5

-> k get pods -n default
No resources found in default namespace.


#### Création d'un site sur GitHub
-> https://github.com/papaFrancky/papafrancky.github.io

cd ${HOME}/code/github
git clone https://github.com/papaFrancky/papaFrancky.github.io
cd papaFrancky.github.io 
echo 'papaFrancky' > index.html
git add index.html
git commit -m 'added index page.'
git push



#### Configuring a Helm Repository

echo $GITHUB_TOKEN | docker login ghcr.io --username $GITHUB_USER  --password-stdin


cd ${HOME}/code/github/gitops-deployments
echo 'papaFrancky' > index.html
git add index.html
git commit -m 'added index.html page'
git push



#### on reprend...

On modifie les alertes Discord pour prendre les événements HelmRepo en compte :
vi notifications/alerts/discord-gitops-alert.yaml
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: discord-gitops-alert
  namespace: default
spec:
  eventSeverity: info
  eventSources:
  - kind: GitRepository
    name: '*'
  - kind: Kustomization
    name: '*'
  - kind: ImagePolicy
    name: '*'
  - kind: HelmRepository
    name: '*'
  providerRef:
    name: discord-gitops

Note : seuls les .spec.eventSources suivantes seraient nécessaires :
  - kind: HelmRepository
    name: '*'


helm show chart oci://ghcr.io/stefanprodan/charts/podinfo

Pulled: ghcr.io/stefanprodan/charts/podinfo:6.5.4
Digest: sha256:a961643aa644f24d66ad05af2cdc8dcf2e349947921c3791fc3b7883f6b1777f
apiVersion: v1
appVersion: 6.5.4
description: Podinfo Helm chart for Kubernetes
home: https://github.com/stefanprodan/podinfo
kubeVersion: '>=1.23.0-0'
maintainers:
- email: stefanprodan@users.noreply.github.com
  name: stefanprodan
name: podinfo
sources:
- https://github.com/stefanprodan/podinfo
version: 6.5.4


export GITHUB_USER=papaFrancky
export GITHUB_TOKEN=$( cat ~/secrets/github.papaFrancky.PAT.FluxCD.txt )
k create secret docker-registry ghcr-charts-auth \
  --docker-server=ghcr.io \
  --docker-username=${GITHUB_USER} \
  --docker-password=-{GITHUB_TOKEN}


##### Ici, pas besoin de créer un secret car le repo helm est public ? :
flux create source helm podinfo \
  --url=https://stefanprodan.github.io/podinfo \
  --namespace=default \
  --interval=1m \
  --export > ${HOME}/code/github/gitops/clusters/sandbox/sources/podinfo.yaml

cat ${HOME}/code/github/gitops/clusters/sandbox/sources/podinfo.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: podinfo
  namespace: default
spec:
  interval: 1m0s
  url: https://stefanprodan.github.io/podinfo


git add && git commit && git push

k get helmrepo 
NAME      URL                                      AGE    READY   STATUS
podinfo   https://stefanprodan.github.io/podinfo   116s   True    stored artifact: revision 'sha256:faeeeb1a7a887b5fe4d440164d29f58ba6f186d46fdf069fd227c39e9fc6ae09'


#### la suite...

cd ${HOME}/code/github/gitops/clusters/sandbox/
mkdir helmreleases
tree
.
├── _backup
│   ├── imagepolicies.tgz
│   ├── imageupdateautomations.tgz
│   ├── kustomizations.tgz
│   └── sources_nginxhello-imagerepository.yaml.tgz
├── flux-system
│   ├── gotk-components.yaml
│   ├── gotk-sync.yaml
│   └── kustomization.yaml
├── helmreleases
├── notifications
│   ├── alerts
│   │   └── discord-gitops-alert.yaml
│   └── providers
│       └── discord-gitops-provider.yaml
└── sources
    ├── nginxhello-source.yaml
    └── podinfo.yaml

https://artifacthub.io/packages/helm/podinfo/podinfo -> tous les paramètres de configuration de podingo :
echo 'ui.message: Hello' > ${HOME}/code/github/gitops/clusters/podinfo.values.yaml

flux create helmrelease podinfo \
  --source=HelmRepository/podinfo \
  --chart=podinfo \
  --values=${HOME}/code/github/gitops/clusters/podinfo.values.yaml \
  --namespace=default \
  --export > ${HOME}/code/github/gitops/clusters/sandbox/helmreleases/podinfo.yaml

cat ${HOME}/code/github/gitops/clusters/sandbox/helmreleases/podinfo.yaml

apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: default
spec:
  chart:
    spec:
      chart: podinfo
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: podinfo
  interval: 1m0s
  values:
    ui.message: Hello ^^

git add && git commit && git push

k get helmreleases
NAME      AGE   READY   STATUS
podinfo   78m   True    Helm install succeeded for release default/podinfo.v1 with chart podinfo@6.5.4


k get po
NAME                      READY   STATUS    RESTARTS   AGE
podinfo-8c4b88bf8-2j8sd   1/1     Running   0          16m


k port-forward service/podinfo 8080:9898                1 ✘  kind-kind ⎈  18:53:06  
Forwarding from 127.0.0.1:8080 -> 9898
Forwarding from [::1]:8080 -> 9898
Handling connection for 8080
-> browser : http://localhost:8080/



##### remediation 

vi ${HOME}/code/github/gitops/clusters/sandbox/helmreleases/podinfo.yaml

---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: default
spec:
  chart:
    spec:
      chart: podinfo
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: podinfo
  interval: 1m0s
  values:
    ui.message: Hello ^^
  upgrade:
    remediation:
      retries: 2

-> Ajout de .spec.upgrade.remedation.retries: 2

