#!/bin/bash

hugo server -b="http://localhost" -s /data/site -d /data/site/public -p 80 --bind=0.0.0.0 --watch --disableLiveReload &

cd /data

while true; do git pull origin master && sleep 60 ; done
