#!/bin/bash
#
# Start LocalStack environment for HPC Bursting Demo testing
# This script starts the LocalStack Docker container and sets up mock AWS resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running or not installed"
  echo "Please start Docker and try again"
  exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose > /dev/null 2>&1; then
  echo "Error: docker-compose is not installed"
  echo "Please install docker-compose and try again"
  exit 1
fi

# Check if LocalStack is already running
if docker ps | grep -q hpc-bursting-localstack; then
  echo "LocalStack is already running, stopping it first..."
  docker-compose down
fi

# Export environment variables for tests to use
export LOCALSTACK_ENDPOINT="http://localhost:4566"
export AWS_ENDPOINT_URL="$LOCALSTACK_ENDPOINT"
export TEST_MODE="true"

# Start LocalStack
echo "Starting LocalStack..."
docker-compose up -d

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
timeout=60
counter=0
while ! curl -s "$LOCALSTACK_ENDPOINT/_localstack/health" | grep -q '"ready": true'; do
  if [ $counter -ge $timeout ]; then
    echo "Error: Timed out waiting for LocalStack to start"
    docker-compose logs
    docker-compose down
    exit 1
  fi
  echo "Waiting for LocalStack to start... ($counter/$timeout seconds)"
  sleep 1
  ((counter++))
done

echo "LocalStack is ready!"
echo "Mock AWS resources have been created via init-aws.sh"
echo
echo "To use the mock AWS environment in your tests, set the following environment variables:"
echo "  export AWS_ENDPOINT_URL=$LOCALSTACK_ENDPOINT"
echo "  export TEST_MODE=true"
echo
echo "To stop LocalStack, run: docker-compose down"