#!/bin/bash
#
# This script contains a number of setup actions which help prepare the dataverse and Skosmos environments.

# Load environment variables
set -a
source .env
set +a
echo "Bootstrap container: $BOOTSTRAP_CONTAINER"
# Setting up submodules and creating the traefik network.
git submodule init && git submodule update

# Setting up solr; including it in docker network and loading our config
cp Skosmos/dockerfiles/config/config-docker-compose.ttl utils/skosmos/config-docker-compose-backup.ttl
cp Skosmos/dockerfiles/docker-compose.yml utils/skosmos/docker-compose-backup.yml

cp utils/skosmos/docker-compose-skosmos.ttl Skosmos/dockerfiles/config/config-docker-compose.ttl
cp utils/skosmos/docker-compose.yml Skosmos/dockerfiles/docker-compose.yml

docker compose -f Skosmos/dockerfiles/docker-compose.yml up -d

# Setting up solr; adding our schema and starting solr. Also adding dataverse to traefik network.

docker compose -f dataverse/docker-compose-dev.yml up -d


# Setup traefik container
docker compose -f utils/traefik/docker-compose.yml up -d

# Function to check if the bootstrap container is still running
is_running() {
  status=$(docker inspect --format='{{.State.Status}}' "$BOOTSTRAP_CONTAINER")
  if [ "$status" = "exited" ]; then
    return 1
  else
    return 0
  fi
}

# Wait for the bootstrap container to finish
echo "Waiting for the bootstrap container to finish..."
while is_running; do
  sleep 5
  echo "Still waiting..."
done

echo "Bootstrapping dataverse has finished!"

# Loading our metadata blocks.
CUSTOM_METADATA_DIR="utils/Custom-Metadata-Blocks/tsv_files/"
cp utils/metadata/* "$CUSTOM_METADATA_DIR"
sh $CUSTOM_METADATA_DIR/upload.sh "$DATAVERSE_CONTAINER"

# Setup subverses and import licenses
sh utils/dataverse/run_py_scripts.sh "$POSTGRES_CONTAINER"

# Setup dutch translation
sh utils/language_setup.sh "$DATAVERSE_CONTAINER"

# Import SOLR schema and config
sh utils/solr/copy_solr.sh "$SOLR_CONTAINER"