+++
date = "2016-08-15T05:08:19Z"
title = "Rajouter du contenu"

+++

Il ne vous reste plus au'à ajouter du contenu.

* Pour cela, il est possible d'utiliser le conteneur de développement avec la commande suivate: docker run --rm  -v /Users/thomas/Development/SCM/hugo/site/:/data/site hugo new getting-started.md

* Finalement, pusher vos changements dans Github: git push origin master

Pour la publication sur le site, ils suffira de builder et runner le conteneur qui sera généré par l'autre Dockerfile sur le serveur

* (à effectuer sur le serveur): git clone https://github.com/tgarlot/docker-patterns

* cd docker-patterns

* Builder le conteneur de développement: docker build -t hugo .

* docker run -d -p 80:80 hugo. Celui ferra un git pull toutes les minutes pour mettre à jour le contenu du site en le générant.
