#!/bin/bash
sudo docker rm  apache_ins
sudo docker build -t apache_img .
sudo docker run --name apache_ins -d -p 80:80 apache_img

sleep 3
sudo docker ps -a
sudo docker logs apache_ins

