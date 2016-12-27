+++
date = "2016-12-26T15:24:18Z"
title = "Installer Docker Swarm avec Vagrant et Ansible"
author = "Thomas Garlot"
tags = [ "Docker Swarm", "Chapitre 11", "Docker 1.12"]
categories = [ "Livre" ]
+++

Nous avons vu dans un post [précédent](/post/docker-swarm-with-docker-1-12/) comment créer un cluster Docker Swarm à l'aide de Docker Machine. Bien qu'efficace, il nous a fallu avoir recours à de nombreuses commandes manuelles, récupérer des tokens... Bref, rien de très reproductible.

C'est là où les outils de  gestion d'infrastructure tel qu' [Ansible](https://www.ansible.com/) entrent en jeux. Couplé avec [Vagrant](https://www.vagrantup.com/), nous allons voir comment nous pouvons facilement monter notre Swarm de manière rapide, automatisée et surtout fiable.

Tout le code nécessaire est disponibe dans le dépôt Github [docker-swarm-with-ansible-vagrant](https://github.com/dunod-docker/docker-swarm-with-ansible-vagrant).

<pre><code class="bash">$ git clone https://github.com/dunod-docker/docker-swarm-with-ansible-vagrant
$ cd dunod-docker/docker-swarm-with-ansible-vagrant
$ ls -1
Vagrantfile
ansible
scripts
</code></pre>

Commençons par regarder la configuration de nos différentes machines virtuelles.

# Notre fichier Vagrant

Tout d'abord, nous créeons nos VMs "swarm worker". Nous utilisons simplement une boucle pour créer 3 VMS swarm-worker-01, swarm-worker-02 et swarm-worker-03.

<pre><code class="ruby">(1..3).each do |i|
  config.vm.define "swarm-worker-0#{i}" do |d|
    d.vm.box = "centos/7"
    d.vm.hostname = "swarm-worker-0#{i}"
    d.vm.network "private_network", ip: "10.100.192.20#{i}"
    d.vm.provider "virtualbox" do |v|
      v.memory = 1024
    end
  end
end
</code></pre>

Puis notre "swarm manager":
<pre><code class="ruby">config.vm.define "swarm-manager" do |d|
  d.vm.box = "centos/7"
  d.vm.hostname = "swarm-manager"
  d.vm.network "private_network", ip: "10.100.192.200"
  d.vm.provision :shell, path: "scripts/bootstrap_ansible.sh"
  d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /vagrant/ansible/playbook.yml -i /vagrant/ansible/hosts/swarm"
  d.vm.provider "virtualbox" do |v|
    v.memory = 1024
  end
</code></pre>

Rien de vraiment nouveau à l'exception des 2 lignes commençant par "d.vm.provision". C'est via ces 2 instructions que nous allons tout d'abord installer Ansible sur notre VM swarm-manager puis lancer ensuite la création de notre cluster Docker Swarm.

# Installation d'Ansible

L'installation se fait simplement à l'aide du script bootstrap_ansible.sh: il installe le dépôt epel et Ansible et copie le ficher de configuration d'Ansible dans /etc/ansible.
<pre><code class="bash">#!/bin/bash
set -e
echo "Installing Ansible..."
yum install -y epel-release
yum update -y
yum install -y  ansible
yum clean all
cp /vagrant/ansible/ansible.cfg /etc/ansible/ansible.cfg
</code></pre>

# Configuration d'Ansible

Nous arrivons dans la partie où Ansible révèle toute sa puissance. Nous allons tout d'abord utiliser un role de [l'Ansible Galaxy](https://galaxy.ansible.com/atosatto/docker-swarm/) qui va:

* Installer le Docker Engine
* Rajouter notre utilisateur "vagrant" au groupe "docker"
* Et finalement configurer automatiquement notre cluster.

Il suffit pour cela de récupérer le code du role et le copier dans le répertoir "roles" d'Ansible puis de le configurer.

## Le fichier playbook.yml

Ce fichier est relativement simple. Il liste simplement les rôles à éxécuter ("{ role: ansible-dockerswarm }"), avec quel utilisateur ("vagrant") et sur quels hôtes de notre inventaire ("all" donc sur toutes nos VMs)

<pre><code class="yaml">- name: "Provision Docker Swarm Cluster"
  hosts: all
  remote_user: vagrant
  roles:
     - { role: ansible-dockerswarm }
</code></pre>

## Le fichier d'inventaire swarm

Localisé dans le répertoire "hosts", ce fichier permet de

* définir toutes nos hôtes et comment s'y connecter ("local" pour le Swarm Manager car Ansible est éxécuté sur cette VM et "ssh" pour les autres. Nous devons alors spécifier l'emplacement des clés SSH à utiliser, ces dernières étant disponibles via le répertoire synchronisé "vagrant")
* de les grouper pour définir lesquels seront des Swarm Manager ou des Swarm Workers. Nous avons 3 groupes:

  + docker_engine: les hôtes sur lesquels le Docker engine doit être installer
  + docker_swarm_manager: les hôtes qui seront des Swarm Managers. Dans notre cas, nous n'aurons n'en aurons qu'un, swarm-manager
  + docker_swarm_worker: les hôtes qui seront des Swarm Workers.

<pre><code class="ini">swarm-manager   ansible_host=10.100.192.200 ansible_connection=local
swarm-worker-01 ansible_host=10.100.192.201 ansible_connection=ssh ansible_ssh_private_key_file=/vagrant/.vagrant/machines/swarm-worker-01/virtualbox/private_key
swarm-worker-02 ansible_host=10.100.192.202 ansible_connection=ssh ansible_ssh_private_key_file=/vagrant/.vagrant/machines/swarm-worker-02/virtualbox/private_key
swarm-worker-03 ansible_host=10.100.192.203 ansible_connection=ssh ansible_ssh_private_key_file=/vagrant/.vagrant/machines/swarm-worker-03/virtualbox/private_key

[docker_engine]
swarm-manager
swarm-worker-01
swarm-worker-02
swarm-worker-03

[docker_swarm_manager]
swarm-manager

[docker_swarm_worker]
swarm-worker-01
swarm-worker-02
swarm-worker-03
</code></pre>

## Configurer la bonne interface réseau

Dans notre setup avec VirtualBox, il faut que nous spécifions l'interface réseau à utiliser ("eth1") par le Docker Engine. Sinon, Ansible utilisera eth0 et donc les mauvaises adresses IP. Il suffit d'éditer le fichier "roles/ansible-dockerswarm/defaults/main.yml" et d'adapter la variable "docker_swarm_interface".

# Création du cluster Swarm

Maintenant que tout est prêt, il ne reste plus qu'a laisser Vagrant/Ansible travailler. Placez vous dans le répertoire qui contient le fichier Vagrantfile et éxécutez la commande:

<pre><code class="bash">$ vagrant up
</code></pre>

Au bout de quelques minutes, vous aurez 4 VMs configurées en cluster et prête à recevoir vos premiers services.
