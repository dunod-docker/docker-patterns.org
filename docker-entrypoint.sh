#!/bin/bash

hugo server -b="http://www.docker-patterns.org" -s /data/site -d /data/site/public -p 80 --bind=0.0.0.0 --watch --appendPort=false --disableLiveReload &

cd /data

while true; do git pull origin master && sleep 60 ; done
