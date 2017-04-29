+++
date = "2017-04-23T15:24:18Z"
title = "Partie 1 - Docker Swarm sur Microsoft Azure - Création d'une image de VM Docker avec Packer"
author = "Thomas Garlot"
tags = [ "Docker Swarm", "Microsoft Azure", "Packer","Terraform"]
categories = [ "Livre" ]
+++

Après avoir vu comment installer un cluster Docker Swarm [localement](/post/docker-swarm-with-ansible-vagrant/), nous allons maintenant nous atteler à créer une configuration plus "cloud" en déployant cette fois-ci notre cluster sur Microsoft Azure.

Pourquoi Microsft Azure? Tout simplement car c'est le bac à sable idéal avec environ 200 euros offerts pendant les 30 premiers jours! C'est donc parfait pour faire nos essais.

Regardons déjà comment faire.

# Microsoft Azure Container Service (ACS)

Microsot Azure fournit en standard un service qui permet de créer directement un cluster Docker, soit avec Docker Swarm mais aussi DCOS ou Kubernetes) avec toutes les ressources Azure requises (répartisseur de charge, réseaux...). Il a cependant quelques désavantages (du moins actuellement):

* Bien que la version du Docker Engine soit récente (17.04.0-ce), la configuration utilise encore _l'ancien mode Swarm (celui qui nécessite un conteneur Swarm et un service de découvert externe type Consul)_ et non pas celui le nouveau inclus dans Docker nativement.
* Il n'est pas possible de spécifier la taille des VMs qui seront créées.

Donc nous allons devoir "reconstruire" cette infrastructure. Pour cela, nous allons tout d'abord utiliser [Packer](http://www.packer.io) pour créer une image de machine virtuelle avec Docker CE puis [Terraform](http://www.terraform.io) pour le reste de l'infrastructure.

Dans ce post, nous allons nous intéresser à l'étape 1 qui est donc de créer notre image et la "pousser" sur Microsoft Azure.

# Création de l'image avec Packer

Pour ceux qui ne connaissent pas encore Packer est, en une ligne, une outil d' [Hashicorp](https://www.hashicorp.com/) qui permet de créer des images à des formats très différents (AMI pour AWS, VirtualBox, QEMU...) à partir d'un fichier de définition au format JSON. Celui que nous allons utiliser est disponible [ici](https://github.com/tgarlot/swarm-on-azure-with-packer-and-terraform.git).

Avant tout, nous allons pour cela avoir besoin:

* D'identifiants pour pouvoir "piloter" Microsoft Azure depuis Packer et Terraform,
* Puis de certaines ressources Microsoft Azure nécessaires à Packer pour stocker l'image de notre VM.

## Création des accès sur Microsoft Azure

Ayant en tête que nous allons utiliser Terraform, le plus simple pour obtenir les identifiants est de tout simplement suivre les instructions disponibles [ici](https://www.terraform.io/docs/providers/azurerm/index.html). Au final, vous disposerez de 4 identifiants nécessaires lors de la phase de build:

* subscription_id: il est disponible en sélectionnant votre profile en haut à droite dans le portal Azure et en allant sur "Mes Permissions"
* client_id / client_secret
* tenant_id

Une fois que vous les avez, pour ne pas avoir à les saisir dans les différents fichiers, le plus simple est de définir pour chacun une variable d'environnement.

<pre><code class="bash"> #Remplacez "..." par les valeurs obtenues ci-dessus
$ export ARM_SUBSCRIPTION_ID=...
$ export ARM_CLIENT_ID=...
$ export ARM_CLIENT_SECRET=...
$ export ARM_TENANT_ID=...
</code></pre>

Nous allons rapidement comment nous en servir.

## Création d'un groupe de ressources et d'un compte de stockage

Les premières "ressources" que nous allons créer sur Microsoft Azure sont:

* Un groupe de ressources: c'est un conteneur (pas au sens Docker) qui permet de regrouper certaines ...ressources (VM, sous-réseau...)!. Plus d'info sur le  [site de Microsfot Azure](https://docs.microsoft.com/fr-fr/azure/azure-resource-manager/resource-group-overview).
* Un compte de stockage Azure: c'est simplement un espace de stockage basé sur un espace de nom unique: chaque objet possède un "point de terminaison" (c.à.d. une URI dans ce cas) unique. C'est là que nous stockerons l'image de notre VM. Plus d'info sur le  [site de Microsfot Azure](https://docs.microsoft.com/fr-fr/azure/storage/storage-create-storage-account.

Pour cela, nous allons créer notre premier script Terraform. En voici le contenu:

<pre><code class="JSON"> #init.tf
resource "azurerm_resource_group" "test" {
  name     = "aztestrg"
  location = "westeurope"
}

resource "azurerm_storage_account" "test" {
  name                = "aztestso"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "westeurope"
  account_type        = "Standard_LRS"
}
</code></pre>

Il est relativement simple:

* Nous créeons tout d'abord notre groupe de ressources avec la directive "azurm_resource_group" et la nommons "attesttrg". "location" nous permet de préciser dans quel zone Azure nous désirons la creér, ici dans la zone "Europe de l'Ouest".
* Nous créeons ensuite notre compte de stockage avec "azurerm_storage_account" et l'incluons dans le groupe de ressouces que nous venons de créer en le référençant avec la variable _${azurerm_resource_group.test.name}_.

Important: Vous remarquerez peu être que notre fichier init.tf ne dispose pas d'un directive [_provider "azurerm"_](https://www.terraform.io/docs/providers/azurerm/index.html). Cela n'est pas nécessaire car Terraform récupère nos variables d'environnement définies ci-dessus et infère qu'il doit utiliser le provider Microsoft Azure. Cela nous permet de stocker nos fichiers dans un répertoire Git sans y stocker des données confidentielles.

Vérifions d'abord que notre script est correct et voir ce qu'il va éxécuter: nous utilisons pour cela la commande "terraform plan"

<pre><code class="bash"> $ terraform plan
...
+ azurerm_resource_group.swarm
    location: "westeurope"
    name:     "azswarmrg"
    tags.%:   "&lt;computed&gt;"

+ azurerm_storage_account.swarm
    access_tier:              "&lt;computed&gt;"
    account_kind:             "Storage"
    account_type:             "Standard_LRS"
    location:                 "westeurope"
    name:                     "azswarmsa"
    primary_access_key:       "&lt;computed&gt;"
    primary_blob_endpoint:    "&lt;computed&gt;"
    primary_file_endpoint:    "&lt;computed&gt;"
    primary_location:         "&lt;computed&gt;"
    primary_queue_endpoint:   "&lt;computed&gt;"
    primary_table_endpoint:   "&lt;computed&gt;"
    resource_group_name:      "azswarmrg"
    secondary_access_key:     "&lt;computed&gt;"
    secondary_blob_endpoint:  "&lt;computed&gt;"
    secondary_location:       "&lt;computed&gt;"
    secondary_queue_endpoint: "&lt;computed&gt;"
    secondary_table_endpoint: "&lt;computed&gt;"
    tags.%:                   "&lt;computed&gt;"

Plan: 2 to add, 0 to change, 0 to destroy.
</code></pre>

Toutes les valeurs marquées comme  "&lt;computed&gt;" seront générées automatiquement lors de l'exécution. Terraform va donc créer (visible avec le signe "+") nos 2 ressources ce qui est confirmé aussi par la dernière ligne "Plan: 2 to add, 0 to change, 0 to destroy". Créons les avec la commande "terraform apply":

<pre><code class="bash"> $ terraform apply
azurerm_resource_group.swarm: Creating...
  location: "" => "westeurope"
  name:     "" => "azswarmrg"
  tags.%:   "" => "<computed>"
azurerm_resource_group.swarm: Creation complete (ID: /subscriptions/1ec96c01-5cd4-448e-9016-92679a0ced65/resourceGroups/azswarmrg)
azurerm_storage_account.swarm: Creating...
  access_tier:              "" => "<computed>"
  account_kind:             "" => "Storage"
  account_type:             "" => "Standard_LRS"
  location:                 "" => "westeurope"
  name:                     "" => "azswarmsa"
  primary_access_key:       "" => "<computed>"
  primary_blob_endpoint:    "" => "<computed>"
  primary_file_endpoint:    "" => "<computed>"
  primary_location:         "" => "<computed>"
  primary_queue_endpoint:   "" => "<computed>"
  primary_table_endpoint:   "" => "<computed>"
  resource_group_name:      "" => "azswarmrg"
  secondary_access_key:     "" => "<computed>"
  secondary_blob_endpoint:  "" => "<computed>"
  secondary_location:       "" => "<computed>"
  secondary_queue_endpoint: "" => "<computed>"
  secondary_table_endpoint: "" => "<computed>"
  tags.%:                   "" => "<computed>"
azurerm_storage_account.swarm: Still creating... (10s elapsed)
azurerm_storage_account.swarm: Still creating... (20s elapsed)
azurerm_storage_account.swarm: Still creating... (30s elapsed)
azurerm_storage_account.swarm: Creation complete (ID: /subscriptions/1ec96c01-5cd4-448e-9016-...soft.Storage/storageAccounts/azswarmsa)

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

The state of your infrastructure has been saved to the path
below. This state is required to modify and destroy your
infrastructure, so keep it safe. To inspect the complete state
use the `terraform show` command.

State path:
</code></pre>

Nous avons maintenant tout ce qu'il nous faut pour créer notre image

## Image avec Packer

Nous utiliserons pour cela le fichier de définition d'image [packer-ubuntu-with-docker.json](https://github.com/tgarlot/swarm-on-azure-with-packer-and-terraform/blob/master/packer-ubuntu-with-docker.json). Regardons le plus en détails.

Nous commençons par définir un bloc "variables":

<pre><code class="json">
"variables": {
"tenant_id": "{{env `ARM_TENANT_ID`}}",
"client_id": "{{env `ARM_CLIENT_ID`}}",
"client_secret": "{{env `ARM_CLIENT_SECRET`}}",
"subscription_id": "{{env `ARM_SUBSCRIPTION_ID`}}"
}
</code></pre>

Ce bloc permet de d'assigner les variables d'environnement que nous avons crée ci-dessus à des variables Packer qui pourront ensuite être utilisées dans le reste de notre fichier.

Nous avons ensuite le bloc "builders", dans notre cas de type "azure_arm":

<pre><code class="json">
"builders": [{
  "type": "azure-arm",
  "client_id": "{{user `client_id`}}",
  "client_secret": "{{user `client_secret`}}",
  "subscription_id": "{{user `subscription_id`}}",
  "tenant_id": "{{user `tenant_id`}}",

  "resource_group_name": "azswarmrg",
  "storage_account": "azswarmsa",

  "capture_container_name": "images",
  "capture_name_prefix": "packer",

  "os_type": "Linux",
  "image_publisher": "Canonical",
  "image_offer": "UbuntuServer",
  "image_sku": "16.04.0-LTS",
  "location": "westeurope",
}]
</code></pre>

* Nous référençons nos 4 variables créées avec la syntax Packer {{user '_nomVariable'}}
* Nous précisons ensuite le groupe de ressource et le compte de stockage que nous avons crée précedement avec Terraform
* Nous donnons ensuite des détails sur notre image:
** Elle sera stockée dans notre compte de stockage dans un répertoire "images"
** Son nom (générée par Microsoft Azure) sera préfixé par "packer"
* Puis nous finissons en spécifiant l'image de base à utilisée (disponible sur la market place Azure) ainsi que sa location

Plus d'info sur le site de Packer et plus particulièrement sur le [builder Azure](https://www.packer.io/docs/builders/azure.html).

Regardons le dernier bloc de notre fichier:

<pre><code class="json">
"provisioners": [{
  "type": "shell",
  "inline": [
    "sudo apt-get update",
    "sudo apt-get install -y apt-transport-https ca-certificates nfs-common",
    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
    "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
    "sudo apt-get update",
    "sudo apt-get install -y docker-ce"
  ]
}]
</code></pre>

ce [shell provisioner](https://www.packer.io/docs/provisioners/shell.html) nous permet simplement d'installer la dernière version de Docker CE. Ce script est exécuté une fois que notre VM "temporaire" est disponible et avant de sauver notre image.

Il ne nous reste ensuite plus qu'à lancer la création de notre image:

<pre><code class="bash">$ packer build packer-ubuntu-with-docker.json
azure-arm output will be in this color.

==> azure-arm: Running builder ...
    azure-arm: Creating Azure Resource Manager (ARM) client ...
==> azure-arm: Creating resource group ...
==> azure-arm:  -> ResourceGroupName : 'packer-Resource-Group-l4bl7ndgd9'
==> azure-arm:  -> Location          : 'westeurope'
==> azure-arm:  -> Tags              :
==> azure-arm: Validating deployment template ...
==> azure-arm:  -> ResourceGroupName : 'packer-Resource-Group-l4bl7ndgd9'
==> azure-arm:  -> DeploymentName    : 'pkrdpl4bl7ndgd9'
==> azure-arm: Deploying deployment template ...
==> azure-arm:  -> ResourceGroupName : 'packer-Resource-Group-l4bl7ndgd9'
==> azure-arm:  -> DeploymentName    : 'pkrdpl4bl7ndgd9'
==> azure-arm: Getting the VM's IP address ...
==> azure-arm:  -> ResourceGroupName   : 'packer-Resource-Group-l4bl7ndgd9'
==> azure-arm:  -> PublicIPAddressName : 'packerPublicIP'
==> azure-arm:  -> NicName             : 'packerNic'
==> azure-arm:  -> Network Connection  : 'PublicEndpoint'
==> azure-arm:  -> IP Address          : '52.233.132.154'
==> azure-arm: Waiting for SSH to become available...
==> azure-arm: Connected to SSH!
...
==> azure-arm: Querying the machine's properties ...
==> azure-arm:  -> ResourceGroupName : 'packer-Resource-Group-l4bl7ndgd9'
==> azure-arm:  -> ComputeName       : 'pkrvml4bl7ndgd9'
==> azure-arm:  -> OS Disk           : 'https://azswarmsa.blob.core.windows.net/images/pkrosl4bl7ndgd9.vhd'
==> azure-arm: Powering off machine ...
==> azure-arm:  -> ResourceGroupName : 'packer-Resource-Group-l4bl7ndgd9'
==> azure-arm:  -> ComputeName       : 'pkrvml4bl7ndgd9'
==> azure-arm: Capturing image ...
==> azure-arm:  -> ResourceGroupName : 'packer-Resource-Group-l4bl7ndgd9'
==> azure-arm:  -> ComputeName       : 'pkrvml4bl7ndgd9'
==> azure-arm: Deleting resource group ...
==> azure-arm:  -> ResourceGroupName : 'packer-Resource-Group-l4bl7ndgd9'
==> azure-arm: Deleting the temporary OS disk ...
==> azure-arm:  -> OS Disk : 'https://azswarmsa.blob.core.windows.net/images/pkrosl4bl7ndgd9.vhd'
Build 'azure-arm' finished.

==> Builds finished. The artifacts of successful builds are:
--> azure-arm: Azure.ResourceManagement.VMImage:

StorageAccountLocation: westeurope
OSDiskUri: https://azswarmsa.blob.core.windows.net/system/Microsoft.Compute/Images/images/packer-osDisk.95707688-1d18-4092-a9ab-611fd06aac83.vhd
OSDiskUriReadOnlySas: https://azswarmsa.blob.core.windows.net/system/Microsoft.Compute/Images/images/packer-osDisk.95707688-1d18-4092-a9ab-611fd06aac83.vhd?se=2017-05-26T20%3A29%3A25Z&sig=%2Bqch%2FhywuNGIKmWuplSQaLCIcCRCP%2FMbVi63dvJTCyc%3D&sp=r&sr=b&sv=2015-02-21
TemplateUri: https://azswarmsa.blob.core.windows.net/system/Microsoft.Compute/Images/images/packer-vmTemplate.95707688-1d18-4092-a9ab-611fd06aac83.json
TemplateUriReadOnlySas: https://azswarmsa.blob.core.windows.net/system/Microsoft.Compute/Images/images/packer-vmTemplate.95707688-1d18-4092-a9ab-611fd06aac83.json?se=2017-05-26T20%3A29%3A25Z&sig=X%2BtArR8i3g%2FNIYIShi1AWCLuob%2BwYGVv4YpraZUxlUc%3D&sp=r&sr=b&sv=2015-02-21
</code></pre>

Pendant la phase de build, si vous vous rendez sur le portail Azure, vous pourrez voir qu'une VM est crée (avec son interface réseau...) puis supprimer une fois que son image a été sauvée au forma .vhd dans notre compte de stockage.

Voilà, nous disposons maintenant d'une image de VM basé sur Ubuntu avec Docker CE d'installer. Nous pouvons maintenant commencer de créer notre Swarm. Commençons par nos [managers Swarms](/post/load-balanced-swarm-managers-on-azure)
