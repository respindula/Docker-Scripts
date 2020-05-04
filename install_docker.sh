#!/bin/bash

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'

# Variables
user=''
password=''
registryResponse=''
port=''
registryName=''
osUser=''



# Checks if user is root or has sudo privileges
osUser=$(whoami)
if [[ $osUser != 'root' ]];
then
	echo -e "${RED}You need to be root or sudo to use this registry installer${NC}"
	exit 1
fi



read -p "$(echo -e ${ORANGE}Registry Name${NC}): " registryName
read -p "$(echo -e ${ORANGE}Registry Port${NC} \(default 5000\)): " port


echo -e "${GREEN}Updating${NC}"
apt-get update > /dev/null

echo -e "${GREEN}Installing Dependencies${NC}"
apt-get install apache2-utils -y > /dev/null


echo -e "${GREEN}Creating directories${NC}"
mkdir -p /opt/dockerRegistries/
mkdir -p /opt/dockerRegistries/data
mkdir -p /opt/dockerRegistries/data/$registryName
mkdir -p /opt/dockerRegistries/extras
mkdir -p /opt/dockerRegistries/authentications
mkdir -p /opt/dockerRegistries/authentications/$registryName
mkdir -p /opt/dockerRegistries/authentications/$registryName/auth
mkdir -p /opt/dockerRegistries/authentications/$registryName/certificate


# Create a certificate
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/dockerRegistries/authentications/$registryName/certificate/domain.key -x509 -days 365 -out /opt/dockerRegistries/authentications/$registryName/certificate/domain.crt

# Reads user and password to be used with the registry
echo -e "${GREEN}Set Login and Password for docker registry${NC}"
read -p "$(echo -e ${ORANGE}User${NC}): " user   
read -p "$(echo -e ${ORANGE}Password${NC}): " password


# Creates htpasswd file that stores user and password
echo -e "${GREEN}Creating authentication file${NC}"
docker run --rm --entrypoint htpasswd registry:2 -Bbn $user $password > /opt/dockerRegistries/authentications/$registryName/auth/htpasswd 2>&1


# Creates registry container
echo -e "${GREEN}Creating registry container${NC}"
if [[ $port == '' ]];
then
	port="5000"
fi

docker run -d -p $port:5000 --restart=always --name $registryName -v /opt/dockerRegistries/authentications/$registryName/certificate:/certs -v /opt/dockerRegistries/authentications/$registryName/auth:/auth -v /opt/dockerRegistries/data:/var/lib/registry -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -e REGISTRY_AUTH=htpasswd registry:2


# Creates a script to call garbage collector everyday at 0300
echo "docker exec $registryName registry garbage-collect /etc/docker/registry/config.yml --delete-untagged=true" >>/opt/dockerRegistries/extras/${registryName}GC.sh
echo "docker restart $registryName" >>/opt/dockerRegistries/extras/${registryName}GC.sh

line="* 3 * * * /bin/bash /opt/dockerRegistries/extras/${registryName}GC.sh >/dev/null 2>&1"
crontab -l > mycron
echo "$line" >> mycron
crontab mycron
rm mycron