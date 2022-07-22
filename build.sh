#!/bin/bash

SERVICE_NAME=${SERVICE_NAME:-docker-zookeeper}

ZK_VER=${ZK_VER:-"3.8.0"}
BUILD_NUMBER=${BUILD_NUMBER:-4dev}

DOCKER_ENGINE_HOST=${DOCKER_ENGINE_HOST:-172.17.0.1}
DOCKER_ENGINE_PORT=${DOCKER_ENGINE_PORT:-2376}

DOCKER_REGISTRY_DOCKERID=${DOCKER_REGISTRY_DOCKERID:-davradocker}
DOCKER_REGISTRY_PASSWORD=${DOCKER_REGISTRY_PASSWORD:-nottellinya}
DOCKER_REGISTRY_NAMESPACE=${DOCKER_REGISTRY_NAMESPACE:-davradocker}

rm -rf build
mkdir build

tar -zcf build/${SERVICE_NAME}.tar.gz --exclude=build --exclude=test .

target_lower=`echo "${SERVICE_NAME}"  | tr '[:upper:]' '[:lower:]'`
target_regname=$target_lower
target_tag=${ZK_VER}_${BUILD_NUMBER}

##################
# BUILD
echo "Build Image: $target_lower:$target_tag" | tee -a build/docker-build.log
curl -g --fail -s -X POST --data-binary "@build/${SERVICE_NAME}.tar.gz" -H "Content-Type:application/gzip" http://${DOCKER_ENGINE_HOST}:${DOCKER_ENGINE_PORT}/build?t=$target_lower:$target_tag'&'nocache'&'buildargs='{"'NPM_KEY'":"'$NPM_KEY'"}' 2>&1 | tee -a docker-build.log
if [ $? -ne 0 ]; then
    exit 1
fi

grep '{"errorDetail"' build/docker-build.log > /dev/null 2>&1
if [ $? -eq 0 ]; then
    exit 1
fi


# Last line will be of form: '{"stream":"Successfully built 55f8bd0d3249\n"}'
image_id=`docker images | grep $target_regname | grep $target_tag | awk '{print $3}'`
echo "Built New Docker ImageId: $image_id"  | tee -a build/docker-build.log


##################
# TAG
echo "Tag to: ${DOCKER_REGISTRY}${DOCKER_REGISTRY_NAMESPACE} as: $target_regname:$target_tag"  | tee -a build/docker-build.log
curl --fail -s -X POST http://${DOCKER_ENGINE_HOST}:${DOCKER_ENGINE_PORT}/images/$image_id/tag?repo=${DOCKER_REGISTRY}${DOCKER_REGISTRY_NAMESPACE}/$target_regname'&'tag=$target_tag 2>&1 | tee -a build/docker-build.log
if [ $? -ne 0 ]; then
    exit 1
fi


##################
# PUSH
echo "Push: $target_regname:$target_tag"  | tee -a docker-build.log
curl --fail -s -X POST -H "Content-Type:application/json" -d "{\"username\": \"${DOCKER_REGISTRY_DOCKERID}\",\"password\": \"${DOCKER_REGISTRY_PASSWORD}\"}" "http://${DOCKER_ENGINE_HOST}:${DOCKER_ENGINE_PORT}/images/${DOCKER_REGISTRY_NAMESPACE}/$target_regname:$target_tag/push" 2>&1 | tee -a build/docker-build.log
if [ $? -ne 0 ]; then
    exit 1
fi

##################
# DELETE BOTH LOCAL IMAGES
echo "Delete images: /$image_id"  | tee -a docker-build.log
curl --fail -s -X DELETE http://${DOCKER_ENGINE_HOST}:${DOCKER_ENGINE_PORT}/images/$image_id?force=true 2>&1 | tee -a build/docker-build.log
if [ $? -ne 0 ]; then
    exit 1
fi
