#!/bin/bash

##Script build a image with more than one architecture and push to a private registry
##It tries to build 20 times each architecture because dotnet core throws a lot of network errors sometimes

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
ORANGE='\033[0;33m'

# Variables
imageName=''
imageVersion=''
registryIP=''
registryPort=''
registryUser=''
registryPassword=''
osUser=''


buildArchitecture () {
	architecture=$1
	imageNameForBuild=$2
	imageVersionForBuild=$3
	fileOutputName=fileOutput${architecture}
	architectureName="armv7"

	if [[ $architecture != "armv7" ]];
	then
		architectureName="$architecture"
	fi

	echo "Building $architecture"

	i=1
	compiledWithoutError='false'
	
	while [ "$i" -le "19" ]
	do
		docker buildx build --load --no-cache --platform linux/$architectureName -t ${imageNameForBuild}${architecture}:${imageVersionForBuild} . 2> $fileOutputName
		value=$(<$fileOutputName)

		if [[ $value != *"Resource temporarily unavailable"* ]];
		then
			compiledWithoutError='true'
			rm $fileOutputName
			echo "$architecture SUCCESS"


			return 0
		else
			echo "Attempt $i failed"
			docker image rm ${imageNameForBuild}${architecture}:${imageVersionForBuild} 2>&1
			rm $fileOutputName

		fi
		let "i += 1"
	done
	
	if [[ $compiledWithoutError == 'false' ]];
	then 
		echo "20 attempts and could not complile $architecture"
		return 1
	fi
}


tagAndPush () {
	architecture=$1
	imageNameForBuild=$2
	imageVersionForBuild=$3
	ipRegistryToPush=$4
	portRegistryToPush=$5

	docker tag $imageNameForBuild$architecture:$imageVersionForBuild $ipRegistryToPush:$portRegistryToPush/temp_$imageNameForBuild$architecture:$imageVersionForBuild
	docker push $ipRegistryToPush:$portRegistryToPush/temp_$imageNameForBuild$architecture:$imageVersionForBuild
}


# Checks if user is root or has sudo privileges
osUser=$(whoami)
if [[ $osUser != 'root' ]];
then
	echo -e "${RED}You need to be root or sudo to use this registry installer${NC}"
	exit 1
fi

docker buildx create --name mybuilder > /dev/null
docker buildx use mybuilder > /dev/null
docker buildx inspect --bootstrap > /dev/null

# enable multi architecture
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes > /dev/null



read -p "$(echo -e What will be the ${GREEN}name of the image${NC}?) " imageName  
read -p "$(echo -e What will be the ${GREEN}version of the image${NC}?) " imageVersion  
read -p "$(echo -e ${GREEN}Registry IP to push:${NC}) " registryIP  
read -p "$(echo -e ${GREEN}Registry PORT to push:${NC}) " registryPort  
read -p "$(echo -e ${GREEN}Registry USER to push:${NC}) " registryUser  
read -p "$(echo -e ${GREEN}Registry PASSWORD to push:${NC}) " registryPassword  

echo -e "${ORANGE}For which architecture you want to build?${NC}"
echo -e "${GREEN}1${NC} - ALL"
echo -e "${GREEN}2${NC} - amd64 + arm64"
echo -e "${GREEN}3${NC} - x86_64 amd64"
echo -e "${GREEN}4${NC} - x86 386"
echo -e "${GREEN}5${NC} - arm64 aarch64"
echo -e "${GREEN}6${NC} - arm arm-v7"


read -p "$(echo -e Number 1- 6:) " buildOption  

if [[ $buildOption == "1" ]];
then

	testamd64='false'
	testarm64='false'
	test386='false'
	testarmv7='false'

	testamd64=$(buildArchitecture "amd64" "$imageName" "$imageVersion")
	testarm64=$(buildArchitecture "arm64" $imageName $imageVersion)
	test386=$(buildArchitecture "386" "$imageName" "$imageVersion")
	testarmv7=$(buildArchitecture "armv7" "$imageName" "$imageVersion")


	if [ "$testamd64" = "false" ] || [ "$testarm64" = "false" ] || [ "$test386" = "false" ] || [ "$testarmv7" = "false" ]
	then
		exit 1
	else
		docker login $registryIP:$registryPort -u $registryUser -p $registryPassword
		tagAndPush 'amd64' "$imageName" "$imageVersion" "$registryIP" "$registryPort"
		tagAndPush 'arm64' "$imageName" "$imageVersion" "$registryIP" "$registryPort"
		tagAndPush "386" "$imageName" "$imageVersion" "$registryIP" "$registryPort"
		tagAndPush "armv7" "$imageName" "$imageVersion" "$registryIP" "$registryPort"

		docker manifest create $registryIP:$registryPort/$imageName:$imageVersion $registryIP:$registryPort/temp_${imageName}arm64:${imageVersion} $registryIP:$registryPort/temp_${imageName}amd64:${imageVersion} $registryIP:$registryPort/temp_${imageName}386:${imageVersion} $registryIP:$registryPort/temp_${imageName}armv7:${imageVersion}
		docker manifest push $registryIP:$registryPort/${imageName}:${imageVersion}
		echo "SUCCESS"

	fi	
	
elif [[ $buildOption == "2" ]];
then

	testamd64='false'
	testarm64='false'
	testamd64=$(buildArchitecture "amd64" "$imageName" "$imageVersion")
	testarm64=$(buildArchitecture "arm64" $imageName $imageVersion)


	if [ "$testamd64" = "false" ] || [ "$testarm64" = "false" ]
	then
		exit 1
	else
		docker login $registryIP:$registryPort -u $registryUser -p $registryPassword
		tagAndPush "amd64" "$imageName" "$imageVersion" "$registryIP" "$registryPort"
		tagAndPush "arm64" "$imageName" "$imageVersion" "$registryIP" "$registryPort"

		docker manifest create $registryIP:$registryPort/${imageName}:${imageVersion} $registryIP:$registryPort/temp_${imageName}arm64:${imageVersion} $registryIP:$registryPort/temp_${imageName}amd64:${imageVersion}
		docker manifest push $registryIP:$registryPort/${imageName}:${imageVersion}
		echo "SUCCESS"

	fi

elif [[ $buildOption == "3" ]];
then
	testamd64='false'
	testamd64=$(buildArchitecture "amd64" "$imageName" "$imageVersion")
	
	if [ "$testamd64" = "false" ] 
	then
		exit 1
	else
		docker login $registryIP:$registryPort -u $registryUser -p $registryPassword
		tagAndPush "amd64" "$imageName" "$imageVersion" "$registryIP" "$registryPort"
		
		docker manifest create $registryIP:$registryPort/${imageName}:${imageVersion} $registryIP:$registryPort/temp_${imageName}amd64:${imageVersion}
		docker manifest push $registryIP:$registryPort/${imageName}:${imageVersion}
		echo "SUCCESS"

	fi	
elif [[ $buildOption == "4" ]];
then
	test386='false'
	test386=$(buildArchitecture "386" "$imageName" "$imageVersion")
	
	if  "$test386" = "false" ]
	then
		exit 1
	else
		docker login $registryIP:$registryPort -u $registryUser -p $registryPassword
		tagAndPush "386" "$imageName" "$imageVersion" "$registryIP" "$registryPort"

		docker manifest create $registryIP:$registryPort/${imageName}:${imageVersion} $registryIP:$registryPort/temp_${imageName}386:${imageVersion}
		docker manifest push $registryIP:$registryPort/${imageName}:${imageVersion}
		echo "SUCCESS"

	fi	

elif [[ $buildOption == "5" ]];
then
	testarm64='false'
	testarm64=$(buildArchitecture "arm64" $imageName $imageVersion)
	

	if [ "$testarm64" = "false" ]
	then
		exit 1
	else
		docker login $registryIP:$registryPort -u $registryUser -p $registryPassword
		tagAndPush "arm64" "$imageName" "$imageVersion" "$registryIP" "$registryPort"

		docker manifest create $registryIP:$registryPort/${imageName}:${imageVersion} $registryIP:$registryPort/temp_${imageName}arm64:${imageVersion}
		docker manifest push $registryIP:$registryPort/${imageName}:${imageVersion}
		echo "SUCCESS"

	fi	

elif [[ $buildOption == "6" ]];
then
	testarmv7='false'
	testarmv7=$(buildArchitecture "armv7" "$imageName" "$imageVersion")


	if [ "$testarmv7" = "false" ]
	then
		exit 1
	else
		docker login $registryIP:$registryPort -u $registryUser -p $registryPassword
		tagAndPush "armv7" "$imageName" "$imageVersion" "$registryIP" "$registryPort"

		docker manifest create $registryIP:$registryPort/${imageName}:${imageVersion} $registryIP:$registryPort/temp_${imageName}armv7:${imageVersion}
		docker manifest push $registryIP:$registryPort/${imageName}:${imageVersion}
		echo "SUCCESS"

	fi	

	
else
	echo "Answer not valid."
	echo "Exiting."
	exit 1
fi


echo -e "${ORANGE}Image $imageName created${NC}"

