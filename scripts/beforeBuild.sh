#!/bin/bash

# validação minima deploy
docker=i$(systemctl status docker)
codedeploy=$(systemctl status codedeploy-agent)
compose=$(docker-compose version)
