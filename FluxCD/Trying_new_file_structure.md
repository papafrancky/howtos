

## Pre-requis
- un cluster Kubernetes pret ( kind create cluster --name=development )
- un repo GitHub nommé ${GITHUB_REPOSITORY}
- un channel Discord avec un channel et un webhook déjà configuré


GITHUB_USERNAME=<my_github_username>
GITHUB_PAT=<my_github_personal_access_token>
GITHUB_REPOSITORY=kubernetes-development

export GITHUB_USER=${GITHUB_USERNAME}
export GITHUB_TOKEN=${GITHUB_PAT}

flux bootstrap github \
  --token-auth \
  --owner ${GITHUB_USER} \
  --repository ${GITHUB_REPOSITORY} \
  --branch=main \
  --path=. \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller

-> Check with your browser :
https://github.com/${GITHUB_USERNAME}/${GITHUB_REPOSITORY}/tree/main

kubectl -n flux-system get all


WORKING_DIRECTORY=/Users/franck/code/github/fluxcd_structure

cd ${WORKING_DIRECTORY}
git clone git@github.com:${GITHUB_USERNAME}/${GITHUB_REPOSITORY}.git
cd ${GITHUB_REPOSITORY}
mkdir -p notifications/{providers,alerts}  

mkdir -p notifications/{providers,alerts}

# Créer un channel nommé ${GITHUB_REPOSITORY} dans son serveur Discord
# Dans les paramètres du channel, intégration, créer un webhook
#   Name : FluxCD
#   URL  : https://discord.com/api/webhooks/1203365724089749525/oi73pVfmSPJp6ujLoEOJWO7z6s9vrVPcqgui3w6VvSj4DF7nx_rZ8BElJFDiYl9XSdc_
# -> on entre l'URL dans un secret Kubernetes
# doc : https://fluxcd.io/flux/components/notification/providers/#discord

DISCORD_WEBHOOK=https://discord.com/api/webhooks/1203365724089749525/oi73pVfmSPJp6ujLoEOJWO7z6s9vrVPcqgui3w6VvSj4DF7nx_rZ8BElJFDiYl9XSdc_
kubectl create secret generic discord-webhook --from-literal=address=${DISCORD_WEBHOOK}

flux create alert-provider discord-fluxcd \
  --type=discord \
  --secret-ref=discord-webhook \
  --channel=${GITHUB_REPOSITORY} \
  --username=FluxCD \
  --namespace=default \
  --export > notifications/providers/discord-fluxcd.yaml

flux create alert discord-fluxcd \
  --event-severity=info \
  --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*' \
  --provider-ref=discord-fluxcd \
  --namespace=default \
  --export > notifications/alerts/discord-fluxcd.yaml

cd ${WORKING_DIRECTORY}/${GITHUB_REPOSITORY}
git st
git add .
git commit -m 'feat: configuring discord alerting.'
git push

kubectl get providers,alerts -n default
NAME                                                     AGE
provider.notification.toolkit.fluxcd.io/discord-fluxcd   54s

NAME                                                  AGE
alert.notification.toolkit.fluxcd.io/discord-fluxcd   54s


# Nous allons organiser les manifests en les regroupant par produit.
# Au même niveau que le répertoire kubernetes-development (ie. notre cluster Kubernetes de développement), nous allons créer un répertoire applications qui contient autant de sous-répertoires qu'il y aura de produits à faire gérer par FluxCD.
# Prenons l'exemple d'une application nommé 'podinfo'.
# Dans GitHub, on créé un nouveau repository nommé podinfo-development.
# Ensuite on utilise le bouton 'import' pour récupérer le projet https://github.com/stefanprodan/podinfo
# -> Nous avons désormais une copie de l'application 'podinfo' dans notre propre repo GitHub 'podingo-development'.

cd ${WORKING_REPOSITORY}
mkdir products && cd products
git clone git@github.com:${GITHUB_USERNAME}/podinfo-development.git
mv podinfo-development podinfo
# -> Nous avons désormais un répertoire 'products/podinfo'. Dans le répertoire kustomize se trouvent les manifests qui nous intéressent pour déployer le produit.

# Notez que nous voulons que le produit soit déployé dans le namespace 'podinfo'.
# !!! Il est donc nécessaire d'ajouter dans les manifests deployment.yaml, hpa.yaml et service.yaml le paramètre suivant : .metadata.namespace=podinfo !!!
# Une fois les manifests modifiés, il faut les commiter et les pousser sur la branche main du repository.
# !!! ce serait intéressant de passer par Flux pour gérer ce paramètre sans modifier les manifests dans leur repo Github.

# Nous allons également profiter de ce moment pour 'downgrader' la version de l'image du conteneur : dans le manifest deployment.yaml, nous allons modifier  '.spec.template.spec.containers[].image' comme suit :
ghcr.io/stefanprodan/podinfo:6.5.4 -> ghcr.io/stefanprodan/podinfo:6.5.0
# Cela nous servira plus tard avec l'ImageAutomation.

# Commençons par créer un namespace dédié à ce produit :

    kubectl create namespace podinfo --dry-run=client -o yaml > namespace.yaml

    cat podinfo/namespace.yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: podinfo

    git add .
    git commit -m 'evol: created podinfo namespace'
    git push

    kubectl get namespace podinfo
    NAME      STATUS   AGE
    podinfo   Active   21s

# Nous devons désormais créer une paire de clés SSH pour permettre à FluxCD de se connecter avec les droits d'écriture au repo applicatif.
flux create secret git podinfo-gitrepository \
  --url=ssh://github.com/${GITHUB_USERNAME}/podinfo-development \
  --namespace=podinfo

# Insérer la clé publique (deploy key) dans les settings du repo GitHub :  https://github.com/${GITHUB_USERNAME}/podinfo-development/settings/keys/new
# title: FluxCD
# Key : ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBL/4WBv909LOgA59QRZS00JC1SgKY0sk8qykde7J+nckCq2gsWQIIwgp9tk6A4JdWyKiKz+No3MIKkMCgcEF7TyEEYtAGyHqeot398ezg48+MZ/rVvaWpvMavzxXT+Thbg==
# !!! Cocher la case 'Allow write access' !!!
# Cliquer sur le bouton "Add Key" et renseigner son mot de passe pour confirmer


cd ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo/

flux create source git podinfo-development \
  --url=ssh://git@github.com/${GITHUB_USERNAME}/podinfo-development.git \
  --branch=main \
  --secret-ref=podinfo-gitrepository \
  --namespace=podinfo \
  --export > gitrepository.yaml

cat gitrepository.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: podinfo-development
  namespace: podinfo
spec:
  interval: 1m0s
  ref:
    branch: main
  secretRef:
    name: podinfo-gitrepository
  url: ssh://git@github.com/papaFrancky/podinfo-development.git

# Définition de la Kustomization qui va avec :
# note : nommer le manifest kustomize.yml pose des problèmes, le nom doit être réservé pour les besoins internes de Flux. Nous le nommerons sync.yaml.
flux create kustomization podinfo \
    --source=GitRepository/podinfo-development.podinfo \
    --path="./kustomize" \
    --prune=true \
    --namespace=podinfo \
    --export > sync.yaml

 cat kustomize.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: podinfo
spec:
  interval: 1m0s
  path: ./kustomize
  prune: true
  sourceRef:
    kind: GitRepository
    name: podinfo-development
    namespace: podinfo

git add .
git commit -m "feat: added podinfo GitRepo + Kustomization."
git push

flux reconcile kustomization flux-system --with-source

kubectl get GitRepositories -n podinfo
NAME                  URL                                                        AGE    READY   STATUS
podinfo-development   ssh://git@github.com/papaFrancky/podinfo-development.git   105m   True    stored artifact for revision 'main@sha1:dc830d02a6e0bcbf63bcc387e8bde57d5627aec2'

kubectl get kustomizations -n podinfo
NAME                  AGE    READY   STATUS
podinfo-development   106m   True    Applied revision: main@sha1:dc830d02a6e0bcbf63bcc387e8bde57d5627aec2



kubectl get all -n podinfo
NAME                           READY   STATUS    RESTARTS   AGE
pod/podinfo-664f9748d8-2d4nf   1/1     Running   0          2m16s
pod/podinfo-664f9748d8-n5gwn   1/1     Running   0          2m1s

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)             AGE
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP             3h50m
service/podinfo      ClusterIP   10.96.175.42   <none>        9898/TCP,9999/TCP   2m16s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/podinfo   2/2     2            2           2m16s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/podinfo-664f9748d8   2         2         2       2m16s

NAME                                          REFERENCE            TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/podinfo   Deployment/podinfo   <unknown>/99%   2         4         2          2m16s



# Nous allons maintenant mettre en place la mise à jour automatique de l'image du conteneur utilisée pour l'application podinfo.
# Pour ce faire, nous allons définir un ImageRepository et une ImagePolicy :

cd ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo

flux create image repository podinfo \
  --image=ghcr.io/stefanprodan/podinfo \
  --interval=5m \
  --namespace=podinfo \
  --export > imagerepository.yaml

cat imagerepository.yaml
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: podinfo
  namespace: podinfo
spec:
  image: ghcr.io/stefanprodan/podinfo
  interval: 5m0s
  
git add .
git commit -m "feat: defined the podinfo image repository."
git push

kubectl describe imagerepository podinfo

apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  creationTimestamp: "2024-02-04T20:45:06Z"
  finalizers:
  - finalizers.fluxcd.io
  generation: 1
  labels:
    kustomize.toolkit.fluxcd.io/name: flux-system
    kustomize.toolkit.fluxcd.io/namespace: flux-system
  name: podinfo
  namespace: podinfo
  resourceVersion: "34713"
  uid: d1124c6d-58f5-4ba4-9202-0bdc67b6a37f
spec:
  exclusionList:
  - ^.*\.sig$
  image: ghcr.io/stefanprodan/podinfo
  interval: 5m0s
  provider: generic
status:
  canonicalImageName: ghcr.io/stefanprodan/podinfo
  conditions:
  - lastTransitionTime: "2024-02-04T20:45:07Z"
    message: 'successful scan: found 51 tags'
    observedGeneration: 1
    reason: Succeeded
    status: "True"
    type: Ready
  lastScanResult:
    latestTags:
    - latest
    - 6.5.4
    - 6.5.3
    - 6.5.2
    - 6.5.1
    - 6.5.0
    - 6.4.1
    - 6.4.0
    - 6.3.6
    - 6.3.5
    scanTime: "2024-02-04T20:45:07Z"
    tagCount: 51
  observedExclusionList:
  - ^.*\.sig$
  observedGeneration: 1

  

flux create image policy podinfo \
  --image-ref=podinfo \
  --select-semver='>=5.4.x' \
  --namespace=podinfo \
  --export > imagepolicy.yaml

cat imagepolicy.yaml
---
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: nginxhello
  namespace: podinfo
spec:
  imageRepositoryRef:
    name: podinfo
  policy:
    semver:
      range: '>=5.4.x'

git add .
git commit -m "feat: defined the podinfo image policy."
git push

kubectl get imagepolicy podinfo -n podinfo
NAME      LATESTIMAGE
podinfo   ghcr.io/stefanprodan/podinfo:6.5.4


# Nous pouvons enfin ajouter un marqueur à notre deployment pour permettre la mise à jour de l'application podinfo via image automation.
cd ${WORKING_DIRECTORY}/products/podinfo-development/kustomize
vi deployment.yaml
Nous allons ajouter un marquer sur le paramètre .spec.template.spec.containers[].image comme suit :
ghcr.io/stefanprodan/podinfo:6.5.0 -> ghcr.io/stefanprodan/podinfo:6.5.0 # {"$imagepolicy": "podinfo:podinfo"}

# "podinfo.podinfo" correspond à "<namespace>.<imagepolicy>"
# doc : https://fluxcd.io/flux/guides/image-update/#configure-image-update-for-custom-resources

# Il nous reste à dfinir une ImageUpdateAutomation
# doc : https://fluxcd.io/flux/cmd/flux_create_image_update/#examples

cd ${WORKING_DIRECTORY}/kubernetes-development/products/podinfo
flux create image update podinfo \
    --namespace=podinfo \
    --git-repo-ref=podinfo-development \
    --git-repo-path="./kustomize" \
    --checkout-branch=main \
    --author-name=FluxCD \
    --author-email=flux@example.com \
    --commit-template="{{range .Updated.Images}}{{println .}}{{end}}" \
    --export > image-update-automation.yaml

cat image-update-automation.yaml

---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: podinfo
  namespace: podinfo
spec:
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: flux@example.com
        name: FluxCD
      messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}'
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: podinfo-development
  update:
    path: ./kustomize
    strategy: Setters
  update:
    path: ./kustomize
    strategy: Setters


cd ${WORKING_DIRECTORY}/products/podinfo-development/kustomize
git fetch # si le manifest a été modifié, nous aurons 1 commit de retard sur notre copie locale.
git pull
grep "image:" deployment.yaml
        image: ghcr.io/stefanprodan/podinfo:6.5.4 # {"$imagepolicy": "podinfo:podinfo"}
-> la version a bien changé

git log

commit 9a10ef5790264c1b415323bc3713c1ee7d5591cb (HEAD -> main, origin/main, origin/HEAD)
Author: FluxCD <flux@example.com>
Date:   Sun Feb 4 21:35:24 2024 +0000

    ghcr.io/stefanprodan/podinfo:6.5.4


kubectl get gitrepository podinfo-development
NAME                  URL                                                        AGE     READY   STATUS
podinfo-development   ssh://git@github.com/papaFrancky/podinfo-development.git   4h17m   True    stored artifact for revision 'main@sha1:9a10ef5790264c1b415323bc3713c1ee7d5591cb'
# -> nous retrouvons le même SHA1.


