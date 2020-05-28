#!/bin/bash

docker=i$(systemctl status docker)
codedeploy=$(systemctl status codedeploy-agent)
compose=$(docker-compose version)
error=$(systemctl status httpd)
