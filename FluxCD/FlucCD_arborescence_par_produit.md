
# FluxCD - Proposition de nouvelle organisation des manifests

Nous voulons tester une manière d'organiser notre repo Flux en suivant une approche par produit/application.

Nous décrirons comment installer from scratch un cluster kubernetes (kind) de développement qui hébergera dans un premier temps une application 'podinfo' récupérée depuis un repo Git dédié.

## Pre-requis
- un cluster Kubernetes pret ( kind create cluster --name=development )
- un repo GitHub nommé _'kubernetes-development'_ dans lequel FluxCD sera bootsrapé;
- un channel Discord avec un channel nommé _'podinfo-development'_ (dédié aux notifications de l'appli podinfo pour l'environnement de développement) et un webhook déjà configuré.


## Bootstrap de FluxCD


    export GITHUB_USER=papaFrancky
    export GITHUB_TOKEN=<my_github_personal_access_token>
    
    flux bootstrap github \
      --token-auth \
      --owner papaFrancky \
      --repository kubernetes-development \
      --branch=main \
      --path=. \
      --personal \
      --components-extra=image-reflector-controller,image-automation-controller

-> Vérification avec un navigateur :

    https://github.com/papaFrancky/kubernetes-development/tree/main

-> Vérification avec kubectl :

    kubectl -n flux-system get all


## Organisation des manifests dans le repository Git dédié à FluxCD

Nous allons organiser les manifests en les regroupant par produit.

Au même niveau que le répertoire _'kubernetes-development'_ (ie. le nom donné à notre cluster Kubernetes de développement), nous allons créer un répertoire _'products'_ qui contiendra les repos Git clonés des produits gérés par FluxCD.
Dans le repo Git de FluxCD, nommé kubernetes-development car il correspond au cluster de développement dans notre exemple, nous décrirons comment Flux gèrera nos produits sur le cluster dans le répertoire products et et dans autant de sous-répertoires qu'il y aura de produits à gérer.

L'arborescence ressemblera à quelque-chose comme ceci :

${WORKING_DIRECTORY}
├── kubernetes-development
│   ├── README.md
│   ├── flux-system
│   │   ├── gotk-components.yaml
│   │   ├── gotk-sync.yaml
│   │   └── kustomization.yaml
│   └── products
│       ├── nginxhello
│       │   ├── ...
│       │   ├── ...
│       │   └── ...
│       └── podinfo
│           ├── git-repository.yaml
│           ├── image-policy.yaml
│           ├── image-repository.yaml
│           ├── image-update-automation.yaml
│           ├── namespace.yaml
│           ├── notification-alert.yaml
│           ├── notification-provider.yaml
│           └── sync.yaml
├── products
│   ├── nginxhello
│   │   ├── ...
│   │   └── ...
│   └── podinfo
│       ├── ...
│       ├── ...
│       ├── ...


## Mise en place de la gestion d'une application par FluxCD

Nous prendrons comme exemple l'application podinfo de Stefan Prodan.
La première chose à faire est de cloner en local notre repo Git dédié à FluxCD pour notre cluster de développement :
    
    cd ${WORKING_DIRECTORY}
    git clone git@github.com:${GITHUB_USERNAME}/kubernetes-development.git
 
Nous allons rassembler tous les manifests de paramétrage dans un répertoire dédié à l'application :

    cd kubernetes-development
    mkdir -p products/podinfo
    cd products/podinfo


### Namespace dédié à l'application

Podinfo disposera de son propre namespace.

    kubectl create namespace podinfo --dry-run=client -o yaml > namespace.yaml

    cat namespace.yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: podinfo

    git add .
    git commit -m 'created namespace podinfo.'
    git push


    kubectl get namespace podinfo

        NAME      STATUS   AGE
        podinfo   Active   21s


### Configuration des notifications (provider: Discord) 

Nous souhaitons être informés via un service de messagerie des modifications apportées à l'application. Notre choix se porte sur Discord.


#### Création du channel Discord dédié à l'application podinfo

Créer un channel nommé podinfo-development dans son 'serveur' Discord et recopier le webhook créé par défaut.


#### Enregistrement du webhook du channel Discord dans un Secret Kubernetes

    DISCORD_WEBHOOK=https://discord.com/api/webhooks/1204170006032818296/D6-rBzJHb1EAfPOtuVbzIqs2goJTuoCn-1AUCef-HZN2xZvK9Mkjolg29dc3z1vqIPuf

    kubectl -n podinfo create secret generic discord-podinfo-development-webhook --from-literal=address=${DISCORD_WEBHOOK} 

    kubectl -n podinfo get secret discord-podinfo-development-webhook
    
      NAME                                  TYPE     DATA   AGE
      discord-podinfo-development-webhook   Opaque   1      134m 


#### Création du 'notification provider'

|||
|---|---|
|doc|https://fluxcd.io/flux/components/notification/providers/#discord|
|||

flux create alert-provider discord \
  --type=discord \
  --secret-ref=discord-webhook \
  --channel=kubernetes-development \
  --username=FluxCD \
  --namespace=podinfo \
  --export > notification-provider.yaml


cat notification-provider.yaml

    ---
    apiVersion: notification.toolkit.fluxcd.io/v1beta3
    kind: Provider
    metadata:
      name: discord
      namespace: podinfo
    spec:
      channel: kubernetes-development
      secretRef:
        name: discord-podinfo-development-webhook
      type: discord
      username: FluxCD


#### Configuration des alertes Discord

    flux create alert discord \
      --event-severity=info \
      --event-source='GitRepository/*,Kustomization/*,ImageRepository/*,ImagePolicy/*,HelmRepository/*' \
      --provider-ref=discord \
      --namespace=podinfo \
      --export > notification-alert.yaml


    cat notifications/alerts/discord.yaml

        ---
        apiVersion: notification.toolkit.fluxcd.io/v1beta3
        kind: Alert
        metadata:
          name: discord
          namespace: podinfo
        spec:
          eventSeverity: info
          eventSources:
          - kind: GitRepository
            name: '*'
          - kind: Kustomization
            name: '*'
          - kind: ImageRepository
            name: '*'
          - kind: ImagePolicy
            name: '*'
          - kind: HelmRepository
            name: '*'
          providerRef:
            name: discord


#### Enregistrement des modifications

    cd ${WORKING_DIRECTORY}/kubernetes-development
    git st
    git add .
    git commit -m 'configuring discord alerting.'
    git push
    
    kubectl get providers,alerts -n podinfo
    
        NAME                                              AGE
        provider.notification.toolkit.fluxcd.io/discord   54s
        
        NAME                                              AGE
        alert.notification.toolkit.fluxcd.io/discord      54s


--- REPRENDRE ICI -----


## Création du repository Git dédié à l'application '_podinfo_'

Pour simuler le développement d'une application, nous allons créer un repository Git sur notre compte à partir d'une application existante : 'podinfo' de Stefan Prodan.

Dans GitHub, on créé un nouveau repository nommé _'podinfo-development'_ ( https://github.com/${GITHUB_USERNAME}/podinfo-development.git ).

Ensuite on utilise le bouton **'import'** pour récupérer le projet https://github.com/stefanprodan/podinfo
-> Nous avons désormais une copie de l'application 'podinfo' dans notre propre repo GitHub 'podingo-development'.

### Récupérons le repository localement dans le répertoire dédié aux produits et renommons-le

Le repository s'appelle podinfo-development car nous partons du principe que le produit disposera d'un repo par environnement.

    cd ${WORKING_DIRECTORY}
    mkdir products && cd products
    git clone git@github.com:${GITHUB_USERNAME}/podinfo-development.git
    mv podinfo-development podinfo

-> Nous avons désormais un répertoire _'products/podinfo'_. Dans le répertoire _'kustomize'_ se trouvent les manifests qui nous intéressent pour déployer le produit.

### Modification des manifests pour déployer l'application dans le namespace éponyme

Notez que nous voulons que le produit soit déployé dans le namespace 'podinfo'.

Il est donc nécessaire d'ajouter dans les manifests deployment.yaml, hpa.yaml et service.yaml le paramètre suivant : 
    
    .data.namespace=podinfo

Une fois les manifests modifiés, il faut les commiter et les pousser sur la branche main du repository.

!!! ce serait intéressant de passer par Flux pour gérer ce paramètre sans modifier les manifests dans leur repo Github !!!

Nous allons également profiter de ce moment pour 'downgrader' la version de l'image du conteneur : dans le manifest _'deployment.yaml'_, nous allons modifier  _''.spec.template.spec.containers[].image''_ comme suit :

    cr.io/stefanprodan/podinfo:6.5.4 -> ghcr.io/stefanprodan/podinfo:6.5.0

Cela nous servira plus tard avec l'ImageAutomation.



### Génération des deploy keys pour le repo GitHub de l'application

Nous devons désormais créer une paire de clés SSH pour permettre à FluxCD de se connecter avec les droits d'écriture au repo applicatif.

    flux create secret git podinfo-gitrepository \
      --url=ssh://github.com/${GITHUB_USERNAME}/podinfo-development \
      --namespace=podinfo

 La clé publique (deploy key) doit être ajoutée dans les settings du repo GitHub :  https://github.com/${GITHUB_USERNAME}/podinfo-development/settings/keys/new

!!! Cocher la case 'Allow write access' !!!

Cliquer sur le bouton "Add Key" et renseigner son mot de passe pour confirmer


### Création du GitRepository 'podinfo-development'

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

### Définition de la Kustomization liée au GitRepo

NOTE : nommer le manifest _'kustomize.yml'_ pose des problèmes, le nom doit être réservé pour les besoins internes de Flux. Nous le nommerons _'sync.yaml'_.

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
        podinfo-development   ssh://git@github.com/papaFrancky/podinfo-development.git   105m   True    stored artifact for     revision     'main@sha1:dc830d02a6e0bcbf63bcc387e8bde57d5627aec2'
    

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



### Mise à jour automatique de l'image

Nous allons maintenant mettre en place la mise à jour automatique de l'image du conteneur utilisée pour l'application podinfo.
Pour ce faire, nous allons définir un ImageRepository et une ImagePolicy :

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


### Ajout d'un marqueur dans le manifest de déploiement

Nous pouvons enfin ajouter un marqueur à notre deployment pour permettre la mise à jour de l'application podinfo via image automation.
    
    cd ${WORKING_DIRECTORY}/products/podinfo-development/kustomize
    vi deployment.yaml

Nous allons ajouter un marquer sur le paramètre .spec.template.spec.containers[].image comme suit :

    ghcr.io/stefanprodan/podinfo:6.5.0 -> ghcr.io/stefanprodan/podinfo:6.5.0 # {"$imagepolicy": "podinfo:podinfo"}

NOTE :

    "podinfo.podinfo" correspond à "<namespace>.<imagepolicy>"

|||
|---|---|
|doc|https://fluxcd.io/flux/guides/image-update/#configure-image-update-for-custom-resources|
|||

### Définition d'une Image Update Automation

Il nous reste à dfinir une ImageUpdateAutomation

|||
|---|---|
|doc|https://fluxcd.io/flux/cmd/flux_create_image_update/#examples|
|||


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
    git fetch     # si le manifest a été modifié, nous aurons 1 commit de retard sur notre copie locale.
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
        podinfo-development   ssh://git@github.com/papaFrancky/podinfo-development.git   4h17m   True    stored artifact for     revision     'main@sha1:9a10ef5790264c1b415323bc3713c1ee7d5591cb'
        
        -> nous retrouvons le même SHA1.


