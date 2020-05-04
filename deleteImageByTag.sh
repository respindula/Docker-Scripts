#!/bin/bash


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
ORANGE='\033[0;33m'

# Variables
catalogResponse=''
needsAuthentication=''
tagsListResponse=''
imageToDelete=''
repoOfImageToDelete=''


# Read the registry IP and Port
read -p "$(echo -e Registry ${GREEN}IP${NC}:) " ip  
read -p "$(echo -e Registry ${GREEN}Port${NC}:) " port 

# Reads the catalog response of server
catalogResponse=$(curl -s -k -X GET http://$ip:$port/v2/_catalog)


# Autentication if registry needs
if [[ $catalogResponse == *"UNAUTHORIZED"* ]];
then
	needsAuthentication="true"
	echo -e "${ORANGE}This server needs authentication.${NC}"
	read -p "$(echo -e Registry ${GREEN}User${NC}:) " user  
	read -p "$(echo -e Registry ${GREEN}Password${NC}:) " password 
	catalogResponse=$(curl -s -k -X GET --user $user:$password http://$ip:$port/v2/_catalog)

	# Checks if user and password are correct
	if [[ catalogResponse == *"UNAUTHORIZED"* ]];
	then
		echo "Wrong User or Password."	
		echo "Exiting."	
		exit 2
	fi
fi

# Prints the catalog to user choose what he wants to delete
echo "$catalogResponse"


# Reads the repository that user wants to delete
read -p "$(echo -e Of what ${GREEN}repository${NC} you want do delete an image?) " repoOfImageToDelete

if [[ $catalogResponse == *"$repoOfImageToDelete"* ]];
then
	if [[ $needsAuthentication == "true" ]];
	then
		tagsListResponse=$(curl -s -k -X GET --user $user:$password http://$ip:$port/v2/$repoOfImageToDelete/tags/list)
	else
		tagsListResponse=$(curl -s -k -X GET http://$ip:$port/v2/$repoOfImageToDelete/tags/list)
	fi

else
	echo "Repository does not exit."
	echo "Exiting."
	exit 3
fi


# Prints the image list to user choose which one he wants to delete
echo "$tagsListResponse"

# Reads the image that user wants to delete
read -p "$(echo -e What ${GREEN}image${NC} you want do delete?) " imageToDelete

# Gets the Content-DigestID of image to use it later
_imageHEAD=''
if [[ $tagsListResponse == *"$imageToDelete"* ]];
then

	if [[ $needsAuthentication == "true" ]];
	then
		_imageHEAD=$(curl -v --user $user:$password -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -k -X GET -I http://$ip:$port/v2/$repoOfImageToDelete/manifests/$imageToDelete 2>&1 | grep Docker-Content-Digest) 2>&1
	else
		_imageHEAD=$(curl -v -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -k -X GET -I http://$ip:$port/v2/$repoOfImageToDelete/manifests/$imageToDelete 2>&1 | grep Docker-Content-Digest) 2>&1
	fi
else
	echo "Image does not exit."
	echo "Exiting."
	exit 4
fi

# Trims Content-DigestID unnecessaries parts
contentDigest=${_imageHEAD/#"< Docker-Content-Digest: "}
contentDigest=${contentDigest/$'\r'/}


# Deletes the image
if [[ $needsAuthentication == "true" ]];
then
    echo -e "${RED}ARE YOU SURE YOU WANT TO DELETE IMAGE $imageToDelete OF REPOSITORY $repoOfImageToDelete?${NC}"
	read -p "$(echo -e \(${RED}y${NC}/${GREEN}n${NC}\)) " deleteAnswer
		if [[ $deleteAnswer == "y" ]];
		then
			curl -k -s --user $user:$password -X DELETE http://$ip:$port/v2/$repoOfImageToDelete/manifests/$contentDigest
			echo "Deleted."
			exit 0
		elif [[ $deleteAnswer == "n" ]];
		then
			echo "Exiting."
		else
			echo "Answer not valid."
			echo "Exiting."
		fi
	
else
	echo -e "${RED}ARE YOU SURE YOU WANT TO DELETE IMAGE $imageToDelete OF REPOSITORY $repoOfImageToDelete?${NC}"
	read -p "$(echo -e \(${RED}y${NC}/${GREEN}n${NC}\)) " deleteAnswer
		if [[ $deleteAnswer == "y" ]];
		then
			curl -k -s -X DELETE http://$ip:$port/v2/$repoOfImageToDelete/manifests/$contentDigest
			echo "Deleted."
			exit 0
		elif [[ $deleteAnswer == "n" ]];
		then
			echo "Exiting."
		else
			echo "Answer not valid."
			echo "Exiting."
		fi
fi


echo "Some error occurred." 
echo "Try deleting mannually." 
