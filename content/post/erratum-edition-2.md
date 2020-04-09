---
title: "Erratum Edition 2 - chapitre 8.2"
date: 2020-03-08T17:31:21+01:00
draft: false
---

# Chapitre 8.2

La commande brctl n'est plus disponible sous CentOS 7.7. il faut utiliser maintenant la commande <code>ìp</code> 

<pre><code class="bash">ip a show docker0</code></pre>

Merci à [herrib](https://github.com/herrib) pour la remarque!