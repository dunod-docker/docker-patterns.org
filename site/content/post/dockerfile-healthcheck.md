+++
date = "2016-09-02T15:24:18Z"
title = "Dockerfile HEALTHCHECK"
author = "Thomas Garlot"
tags = [ "Dockerfile", "Chapitre 7", "Docker 1.12"]
categories = [ "Livre" ]
+++

Une autre nouveauté de Docker v1.12 est l'ajout de l'instruction [HEALTHCHECK](https://docs.docker.com/engine/reference/builder/#/healthcheck) pour le Dockerfile.

En effet, avec le nouveau mode Swarm, un *docker ps* n'est plus suffisant: si le conteneur "tourne" mais que l'application à l'intérieur du conteneur ne renvoie que des erreurs, comment Docker Swarm peut-il savoir qu'il doit redémarrer le conteneur? C'est là que la l'instruction HEALTHCHECK entre en jeux. Avant Docker 1.12, il fallait utiliser des mécanismes tel que [les health checks de Consul](https://www.consul.io/intro/getting-started/checks.html) ou [ceux de Mesosphere](https://mesosphere.github.io/marathon/docs/health-checks.html). Bien qu'efficace, cette méthode obligeait à gérer ces scripts à l'extérieur du conteneur.

l'instruction HEALTHCHECK permet de spécifier une commande qui permettra de savoir si le conteneur peut "traiter des demandes". Regardons cela de manière concrète.

Récupérez tout d'avoir le dépot Github qui contient les fichiers nécessaire

<pre><code class="bash">$ git clone https://github.com/dunod-docker/docker-healthcheck.git
$ cd docker-healthcheck/
$ ls -1
Dockerfile
README.md
app.py
requirements.txt
</code></pre>

Il contient simplement:

* app.py: un fichier "Hello World" basé sur le framework [Flask](http://flask.pocoo.org/)
* requirements.txt: spécifie la version de Flask à utiliser
* Dockerfile: ce dernier ne fait qu'installer Python et pip, copier les 2 fichiers app.py et requirements.txt, et exposer l'application sur le port 5000.


<pre><code class="dockerfile">FROM centos:7

RUN yum install -y epel-release && \
    yum update -y && \
    yum install -y  python-pip python-dev curl vim && \
    yum clean all

RUN pip install -r requirements.txt

COPY . /app

WORKDIR /app

HEALTHCHECK --interval=10s --retries=2 CMD curl -f http://localhost:5000/ || exit 1

EXPOSE 5000

ENTRYPOINT [ "python" ]

CMD [ "app.py" ]
</code></pre>

Et bien sur, nous avons notre nouvelle directive HEALTHCHECK. Nous définissons l'interval entre 2 checks (10s, 30s par défaut) ainsi que le nombre de tentatives (2, 3 par défaut) qui doivent échouer pour considérer que notre container n'est plus "healthy". Nous aurions aussi pu spécifier un 3ème paramêtre *--timeout* qui comme son nom l'indique, considère que le check est négatif si la commande met plus de 30 secondes (valeur par défaut) pour s'éxécuter.

Notre healthcheck est décrit après *CMD*, dans notre cas, <code class="bash">curl -f http://localhost:5000/ || exit 1</code>. Docker accepte soit une commande shell soit une commande en mode "éxécution". Dans notre cas, nous mettons directement une commande shell sachant que nous aurions tout aussi bien pu référencer un fichier *.sh.

Construisons et démarrons notre container:

<pre><code class="bash">$ docker build -t flask .
$ docker run -d -p 5000:5000 --name flask flask
$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                            PORTS                    NAMES
37b7f72fa9d6        flask               "python app.py"          2 seconds ago       Up 1 seconds (health: starting)   0.0.0.0:5000->5000/tcp   flask
</code></pre>

Le status de notre container est tout d'abord **health: starting** puis après quelques secondes (le temps que le premier check est passé), passe à **healthy**. Nous pouvons aussi le voir simplement avec la commande:
<pre><code class="bash">$ docker inspect --format='{{json .State.Health.Status}}' flask
"healthy"
</code></pre>

Pour voir ce qu'il se passe quand notre application a un problème, nous allons tout simplement en simuer un! Pour cela, nous allons la modifier pour qu'elle renvoie un statut HTTP 500, qui fera échoué notre check.

<pre><code class="bash">$ docker exec -it flask /bin/bash
[root@37b7f72fa9d6 app]# vi app.py

@app.route('/')
def hello_world():
    return 'Internal Server Error', 500

:wq
$ exit
</code></pre>

Si nous attendons quelques secondes, notre conteneur est maintenant "unhealthy":
<pre><code class="bash">$ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED          STATUS                  PORTS                    NAMES
37b7f72fa9d6        flask               "python app.py"          1 hour ago       Up 1 hour (unhealthy)   0.0.0.0:5000->5000/tcp   flask
</code></pre>

Grâce à la nouvelle directive HEALTHCHECK, il est maintenant possible de savoir facilement si le conteneur fournit son service. Il est conseillé d'avoir des checks de "haut niveau" tel une URL HTTP qui vérifie que l'application packagée dans le conteneur fournit effectivement son service.
