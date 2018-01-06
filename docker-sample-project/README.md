# *Project Title*

**This Docker image is not aimed at public consumption.
It exists to serve as a single endpoint for SICZ projects.**

*One Paragraph of project description goes here*

## Contents

This container only contains essential components:
* [*BASE IMAGE NAME*](https://github.com/*AUTHOR*/*BASE IMAGE REPOSITORY*) provide *BASE IMAGE DESCRIPTION*.
* [*PROJECT*](*PROJECT URL*) *PROJECT DESCRIPTION*.

## Getting started

These instructions will get you a copy of the project up and running on your
local machine for development and testing purposes. See deployment for notes
on how to deploy the project on a live system.

### Prerequisities

*What things you need to install the software and how to install them*

### Installing

*A step by step series of examples that tell you have to get a development env running*

Clone the GitHub repository into your working directory:
```bash
git clone https://github.com/*AUTHOR*/*REPOSITORY*
```

### Usage

[*A step by step series of examples that tell you how to build and run Docker container*]

Use the command `make` to simplify the Docker container development tasks:
```bash
make all                # Build a new image and run the tests
make ci                 # Build a new image and run the tests
make build              # Build a new image
make rebuild            # Build a new image without using the Docker layer caching
make config-file        # Display the configuration file for the current configuration
make vars               # Display the make variables for the current configuration
make up                 # Remove the containers and then run them fresh
make create             # Create the containers
make start              # Start the containers
make stop               # Stop the containers
make restart            # Restart the containers
make rm                 # Remove the containers
make wait               # Wait for the start of the containers
make ps                 # Display running containers
make logs               # Display the container logs
make logs-tail          # Follow the container logs
make shell              # Run the shell in the container
make test               # Run the tests
make test-all           # Run tests for all configurations
make test-shell         # Run the shell in the test container
make secrets            # Create the Simple CA secrets
make clean              # Remove all containers and work files
make docker-pull        # Pull all images from the Docker Registry
make docker-pull-baseimage    # Pull the base image from the Docker Registry
make docker-pull-dependencies # Pull the project image dependencies from the Docker Registry
make docker-pull-image  # Pull the project image from the Docker Registry
make docker-pull-testimage # Pull the test image from the Docker Registry
make docker-push        # Push the project image into the Docker Registry
```

## Deployment

*Add additional notes about how to deploy this on a live system*

You can start with this sample `docker-compose.yml` file:
```yaml
services:
  *PROJECT*:
    image: *IMAGE_NAME*
    environment:
    ports:
    volumes:
```

## Authors

* [*AUTHOR*](https://github.com/*AUTHOR*) - Initial work.

See also the list of
[contributors](https://github.com/*AUTHOR*/*REPOSITORY*/contributors)
who participated in this project.

## License

This project is licensed under the Apache License, Version 2.0 - see the
[LICENSE](LICENSE) file for details.

## Acknowledgments

*A hat tip to anyone who's code or inspiration was used*
