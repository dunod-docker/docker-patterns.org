---
title: "Erratum Edition 2"
date: 2020-04-08T17:31:21+01:00
draft: false
---

# Chapitre 3.3.2

la commande <pre>socat -v UNIX-LISTEN:/tmp/socatproxy.sock, fork, reuseaddr UNIX-CONNECT:/var/run/docker.sock &</pre> renvoie une erreur si elle est utilisée avec Docker Desktop for mac.

Il faut la remplacer par <pre>socat -v UNIX-LISTEN:/tmp/socatproxy.sock, UNIX-CONNECT:/var/run/docker.sock &</pre>.


# Chapitre 8.2

La commande brctl n'est plus disponible sous CentOS 7.7. il faut utiliser maintenant la commande <code>ìp</code> 

<pre><code class="bash">ip a show docker0</code></pre>



Merci à [herrib](https://github.com/herrib) pour les 2 issues levées sur GitHub !!