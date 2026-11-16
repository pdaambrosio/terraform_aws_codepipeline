#!/bin/bash

# validação minima deploy
wait=$(sleep 60)
docker=$(systemctl status docker)
codedeploy=$(systemctl status codedeploy-agent)
compose=$(docker-compose version)
