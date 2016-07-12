#!/bin/bash

sudo docker rm -v $(docker ps -a -q -f status=exited)
sudo docker rmi $(docker images -f "dangling=true" -q)
sudo docker run -v /var/run/docker.sock:/var/run/docker.sock -v 
sudo /var/lib/docker:/var/lib/docker --rm martin/docker-cleanup-volumes
