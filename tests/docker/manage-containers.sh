#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Scott Friedman
#
# Manage Docker containers for HPC Bursting Demo testing
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_usage() {
  echo "Usage: $0 [command]"
  echo "Commands:"
  echo "  start         Start the containers"
  echo "  stop          Stop the containers"
  echo "  restart       Restart the containers"
  echo "  status        Show the status of the containers"
  echo "  logs          Show the logs of the containers"
  echo "  exec-control  Execute a command in the controller container"
  echo "  exec-compute  Execute a command in the compute container"
  echo "  test          Run the test suite"
  echo "  clean         Stop containers and remove volumes"
  echo "  help          Show this help message"
}

start_containers() {
  echo "Starting containers..."
  docker-compose up -d
  
  # Wait for containers to be ready
  echo "Waiting for containers to be ready..."
  sleep 5
  
  echo "Containers started. Access controller with:"
  echo "  ./manage-containers.sh exec-control bash"
}

stop_containers() {
  echo "Stopping containers..."
  docker-compose down
}

restart_containers() {
  stop_containers
  start_containers
}

show_status() {
  echo "Container status:"
  docker-compose ps
}

show_logs() {
  docker-compose logs
}

exec_controller() {
  if [ $# -eq 0 ]; then
    docker-compose exec hpc_controller bash
  else
    docker-compose exec hpc_controller "$@"
  fi
}

exec_compute() {
  if [ $# -eq 0 ]; then
    docker-compose exec hpc_compute bash
  else
    docker-compose exec hpc_compute "$@"
  fi
}

run_tests() {
  echo "Running tests in container..."
  docker-compose exec hpc_controller bash -c "cd /app && ./tests/docker/run-tests.sh"
}

clean_environment() {
  echo "Cleaning up containers and volumes..."
  docker-compose down -v
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Docker is not installed. Please install Docker first."
  exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
  echo "Docker is not running. Please start Docker first."
  exit 1
fi

# Handle commands
if [ $# -eq 0 ]; then
  print_usage
  exit 0
fi

command="$1"
shift

case "$command" in
  start)
    start_containers
    ;;
  stop)
    stop_containers
    ;;
  restart)
    restart_containers
    ;;
  status)
    show_status
    ;;
  logs)
    show_logs
    ;;
  exec-control)
    exec_controller "$@"
    ;;
  exec-compute)
    exec_compute "$@"
    ;;
  test)
    run_tests
    ;;
  clean)
    clean_environment
    ;;
  help)
    print_usage
    ;;
  *)
    echo "Unknown command: $command"
    print_usage
    exit 1
    ;;
esac