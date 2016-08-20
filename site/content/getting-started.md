+++
date = "2016-08-14T19:59:59Z"
title = "Getting started"


+++

L'installation est très simple:

* git clone https://github.com/tgarlot/docker-patterns

* cd docker-patterns

* Builder le conteneur de développement: docker build -f Dockerfile.dev -t hugo_dev .

* Puis lancer le en montant le répertoire /site comme volume: docker run -d -p 8080:8080 --name=hugo -v /Users/thomas/Development/SCM/hugo/site/:/data/site hugo
