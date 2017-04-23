#!/bin/bash

debug0 "Processing $(basename ${DOCKER_ENTRYPOINT:-$0})"

# Default command
: ${DOCKER_COMMAND:=[*COMMAND*]}

# First arg is option (-o or --option)
if [ "${1:0:1}" = '-' ]; then
	set -- ${DOCKER_COMMAND} "$@"
fi
