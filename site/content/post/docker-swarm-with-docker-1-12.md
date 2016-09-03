+++
date = "2016-08-28T15:24:18Z"
title = "Docker Swarm avec Docker 1.12 - Partie 1"
author = "Thomas Garlot"
tags = [ "Docker Swarm", "Chapitre 11", "Docker 1.12"]
categories = [ "Livre" ]
+++

Fin juin, Docker Inc. a publié la dernière version du Docker Engine v1.12. C'est certainement la plus importante depuis la version v1.9 et Docker Swarm qui devenait "Production ready".

En effet, Docker Swarm est maintenant intégré directment dans le Docker Engine: plus besoin de conteneurs séparés sur chaque noeud ni de service de registre tel que {{< url-link "Consul" "http://consul.io/" >}} ou {{< url-link "Etcd" "https://github.com/coreos/etcd" >}}. Regardons concrètement comment cela fonctionne.

# Préparation de l'environnement

Le plus simple est d'utiliser Docker Machine (v0.8+) qui contient le Docker Engine 1.12+ disponible avec {{< url-link "Docker Toolbox" "https://docs.docker.com/toolbox/overview/" >}} ou {{< url-link "Docker for Mac" "https://docs.docker.com/docker-for-mac/" >}}/{{< url-link "Docker for Windows" "https://docs.docker.com/docker-for-windows/" >}}. Créons 4 machines pour simuler notre cluster Swarm

<pre><code class="bash">$ docker-machine create -d virtualbox node-01
$ docker-machine create -d virtualbox node-02
$ docker-machine create -d virtualbox node-03
$ docker-machine create -d virtualbox node-04
$ docker-machine ls
NAME      ACTIVE   DRIVER       STATE     URL                         SWARM   DOCKER    ERRORS
node-01   -        virtualbox   Running   tcp://192.168.99.101:2376           v1.12.1   
node-02   -        virtualbox   Running   tcp://192.168.99.102:2376           v1.12.1   
node-03   -        virtualbox   Running   tcp://192.168.99.103:2376           v1.12.1  
node-04   -        virtualbox   Running   tcp://192.168.99.104:2376           v1.12.1
</code></pre>

Nous remarquons tout d'abord qu'il n'est plus nécessaire de passer à Docker Machine des paramêtres tels que *---swarm*, *--swarm-master* ou *--swarm-discovery*. En effet, Docker Swarm est directement inclu dans le Docker engine avec un registre intégré. L'installation s'en trouve grandement simplifiée.

Initialisons notre cluster Swarm avec la command {{< url-link "docker swarm init" "https://docs.docker.com/engine/reference/commandline/swarm_init/" >}}

<pre><code class="bash">$ eval $(docker-machine env node-01)
$ docker swarm init --advertise-addr $(docker-machine ip node-01):2377 --listen-addr $(docker-machine ip node-01):2377
Swarm initialized: current node (ai223orm5n2b8fdbkic3leyfd) is now a manager.

To add a worker to this swarm, run the following command:
    docker swarm join \
    --token SWMTKN-1-2gy01eojntwo8grvj7wgh0k21phiemtd6uy3lh8rj76pk4asic-cwdm8622ryxwlljggrfndk3im \
    192.168.99.101:2377

To add a manager to this swarm, run the following command:
    docker swarm join \
    --token SWMTKN-1-2gy01eojntwo8grvj7wgh0k21phiemtd6uy3lh8rj76pk4asic-45t2j0uokgb7kn84jx4g50gr0 \
    192.168.99.101:2377
</code></pre>

Regardons un peu les différents paramètres :

* --advertise-addr: c'est l'adresse qui sera publiée aux autres membres du cluster pour accéder à l'API Swarm. Il n'est obligatoire que dans le cas ou le système dispose de plusieurs adresses IP sinon Docker utilisera l'adresse IP du système. Nous spécifions aussi le port (2377) qui est aussi le port par défaut utilisé.
* --listen-addr: c'est l'adresse/port utilisé par le Docker Swarm Manager. Par défaut, sa valeur est 0.0.0.0:2377.

Le nouveau Docker Swarm dispose de 2 types de noeuds:

* Les noeuds Manager: c'est "l'ancien" Swarm Master. C'est à lui que les commandes de gestion de *service* sont envoyées. Il est recommandé d'avoir plusieurs noeuds Manager si l'on souhaite réaliser une système à haute disponibilité. Les managers élisent ensuite un Leader via un mécanisme de consensus basé sur l'algorithme {{< url-link "Raft" "http://thesecretlivesofdata.com/raft/" >}} qui distribuera ensuite les commandes au noeuds Worker.
* Les noeuds Worker: ils reçoivent et éxécutent les tâches des noeuds Manager. Par défaut, un noeud Manager est aussi un Worker.

Rajoutons maintenant notre node-02 au cluster Swarm en tant que Manager. Pour cela, nous utilisons la commande  {{< url-link "docker swarm join" "https://docs.docker.com/engine/reference/commandline/swarm_join/" >}} en utilisant le token "manager" de la commande *swarm init*

<pre><code class="bash">$ eval $(docker-machine env node-02)
$ docker swarm join --token SWMTKN-1-2gy01eojntwo8grvj7wgh0k21phiemtd6uy3lh8rj76pk4asic-45t2j0uokgb7kn84jx4g50gr0 $(docker-machine ip node-01)
This node joined a swarm as a manager.
$ docker node ls
ID                           HOSTNAME  STATUS  AVAILABILITY  MANAGER STATUS
ai223orm5n2b8fdbkic3leyfd    node-01   Ready   Active        Leader
ck1gmrsra3jq6pkds1sdfia1f *  node-02   Ready   Active        Reachable
</code></pre>

Nous utilisons la nouvelle commande {{< url-link "docker node ls" "https://docs.docker.com/engine/reference/commandline/node_ls/" >}} pour lister les noeuds de notre cluster Swarm. Nous voyons bien que nous avons 2 Master, un étant le Leader (node-01) et le deuxième un "Master passif". Nous pouvons facilement observer la communication entre ces 2 noeuds en regardant dans les logs du Docker Engine:

<pre><code class="bash">$ docker-machine ssh node-01
docker@node-01:~$ tail -f /var/log/docker.log
ime="2016-08-31T05:31:52.362136587Z" level=debug msg="2016/08/31 05:31:52 [DEBUG] memberlist: TCP connection from=192.168.99.102:45978\n"
time="2016-08-31T05:31:55.727156295Z" level=debug msg="2016/08/31 05:31:55 [DEBUG] memberlist: Initiating push/pull sync with: 192.168.99.102:7946\n"
time="2016-08-31T05:32:01.794360269Z" level=debug msg="2016/08/31 05:32:01 [DEBUG] memberlist: TCP connection from=192.168.99.102:45980\n"
time="2016-08-31T05:32:01.794660886Z" level=debug msg="node-01: Initiating bulk sync for networks [7hlr74rtdldopgf0hvc17bl7c] with node node-02"
time="2016-08-31T05:32:22.355619380Z" level=debug msg="2016/08/31 05:32:22 [DEBUG] memberlist: TCP connection from=192.168.99.102:45982\n"
time="2016-08-31T05:32:25.730119651Z" level=debug msg="2016/08/31 05:32:25 [DEBUG] memberlist: Initiating push/pull sync with: 192.168.99.102:7946\n"
time="2016-08-31T05:32:31.784696404Z" level=debug msg="2016/08/31 05:32:31 [DEBUG] memberlist: TCP connection from=192.168.99.102:45984\n"
time="2016-08-31T05:32:31.785175172Z" level=debug msg="node-01: Initiating bulk sync for networks [7hlr74rtdldopgf0hvc17bl7c] with node node-02"
</code></pre>

> Attention, pour avoir un cluster Swarm à haute disponibilité, il faut au moins {{< url-link "3 Swarm Master " "https://docs.docker.com/engine/swarm/admin_guide/#/add-manager-nodes-for-fault-tolerance" >}}!!

Nous pouvons maintenant rajouter nos 2 derniers noeuds Worker:

<pre><code class="bash">$ eval $(docker-machine env node-03)
$ docker swarm join --token SWMTKN-1-2gy01eojntwo8grvj7wgh0k21phiemtd6uy3lh8rj76pk4asic-cwdm8622ryxwlljggrfndk3im $(docker-machine ip node-01)
This node joined a swarm as a worker.
$ docker swarm join-token --rotate worker
To add a worker to this swarm, run the following command:
    docker swarm join \
    --token SWMTKN-1-2gy01eojntwo8grvj7wgh0k21phiemtd6uy3lh8rj76pk4asic-f1idpyltr2fjazwbgq4p5tt4a \
    192.168.99.101:2377
$ eval $(docker-machine env node-04)
$ docker swarm join --token SWMTKN-1-2gy01eojntwo8grvj7wgh0k21phiemtd6uy3lh8rj76pk4asic-cwdm8622ryxwlljggrfndk3im $(docker-machine ip node-01)
Error response from daemon: rpc error: code = 3 desc = A valid join token is necessary to join this cluster
$ docker swarm join --token SWMTKN-1-2gy01eojntwo8grvj7wgh0k21phiemtd6uy3lh8rj76pk4asic-f1idpyltr2fjazwbgq4p5tt4a $(docker-machine ip node-01)
This node joined a swarm as a worker.
</code></pre>

Vous remarquerez que nous avons utilisé la commande {{< url-link "docker swarm join-token" "https://docs.docker.com/engine/reference/commandline/swarm_join_token/" >}} qui permet de récupérer ou de renouveler le token utilisé pour attacher les noeuds au cluster Swarm. Le/les tokens générés précedemment ne sont évidemment plus valables.

Nous avons un cluster  Swarm totalement fonctionnel. Pour information, voici quelques commandes qui permettent de modifier les noeuds du cluster ainsi que leur role.

| Commande      | Action        |
| ------------- |-------------|
| docker node promote <node>  | Promeut un noeud de Worker a Manager|
| docker node demote <node>     | Change un noeud Manager en noeud Worker      |
| docker swarm leave | Enlève le noeud du cluster (à exécuter sur le noeud lui-même)      |

Dégradons le noeud 2 de Manager à Worker pour finalement n'avoir qu'un Master et 3 workers

<pre><code class="bash">$ eval $(docker-machine env node-01)
$ docker node demote node-02
Manager node-02 demoted in the swarm.
mac-book-air:site thomas$ docker node ls
ID                           HOSTNAME  STATUS  AVAILABILITY  MANAGER STATUS
25io9rn7fbh2v3hfbtrxx6eug    node-03   Ready   Active        
4b3yneia85sq05fo22s7jl6zw    node-04   Ready   Active        
ai223orm5n2b8fdbkic3leyfd *  node-01   Ready   Active        Leader
ck1gmrsra3jq6pkds1sdfia1f    node-02   Ready   Active        
</code></pre>

Il ne nous reste plus qu'a déployer nos containers. Ce que nous verrons dans un prochain post.
