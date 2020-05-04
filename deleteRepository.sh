#!/bin/bash

##Script to delete a repository and all its images (SERVER SIDE)


# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Variables
registryRegistryName=''
repositoryName=''
registryResponse=''

read -p "$(echo -e What is the ${GREEN}container\'s name of registry${NC}? ) " registryRegistryName


registryResponse=$(docker exec -it $registryRegistryName ls /var/lib/registry/docker/registry/v2/repositories 2>&1) 


if [[ $registryResponse == *"Error"* ]];
then
	echo "Image does not exit."
	echo "Exiting."
	exit 1
fi

echo -e "${GREEN}LIST OF REPOSITORIES${NC}? "
echo "$registryResponse"

read -p "$(echo -e What is the ${GREEN}name of the repository${NC} you want to ${RED}delete?${NC} ) " repositoryName

if [[ $registryResponse != *"$repositoryName"* ]];
then
	echo "Repository does not exit."
	echo "Exiting."
	exit 2
fi


echo -e "${RED}ARE YOU SURE YOU WANT TO DELETE THE ENTIRE REPOSITORY $repositoryName?${NC}"
read -p "$(echo -e \(${RED}y${NC}/${GREEN}n${NC}\)) " deleteAnswer

if [[ $deleteAnswer == "y" ]];
then
	docker exec -it $registryRegistryName rm -rf /var/lib/registry/docker/registry/v2/repositories/$repositoryName 2>&1
	echo "Deleted."
	exit 0
elif [[ $deleteAnswer == "n" ]];
then
	echo "Exiting."
else
	echo "Answer not valid."
	echo "Exiting."
fi
