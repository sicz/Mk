# [*Project Title*]

**This Docker image is not aimed at public consumption.
It exists to serve as a single endpoint for SICZ projects.**

[*One Paragraph of project description goes here*]

## Contents

This container only contains essential components:
* [[*BASE IMAGE NAME*]](https://github.com/[*AUTHOR*]/[*BASE IMAGE REPOSITORY*]) provide [*BASE IMAGE DESCRIPTION*].
* [*PROJECT*]([*PROJECT URL*]) [*PROJECT DESCRIPTION*].

## Getting started

These instructions will get you a copy of the project up and running on your
local machine for development and testing purposes. See deployment for notes
on how to deploy the project on a live system.

### Prerequisities

[*What things you need to install the software and how to install them*]

### Installing

[*A step by step series of examples that tell you have to get a development env running*]

Clone GitHub repository to your working directory:
```bash
git clone https://github.com/[*AUTHOR*]/[*REPOSITORY*]
```

### Usage

[*A step by step series of examples that tell you how to build and run Docker container*]

Use command `make` to simplify Docker container development tasks:
```bash
make all        # Destroy running container, build new image and run tests
make build      # Build new image
make rebuild    # Build new image without caching
make run        # Run container
make stop       # Stop running container
make start      # Start stopped container
make restart    # Restart container
make status     # Show container status
make logs       # Show container logs
make logs-tail  # Connect to container logs
make shell      # Open shell in running container
make test       # Run tests
make rm         # Destroy running container
make clean      # Destroy running container and clean
```

## Deployment

[*Add additional notes about how to deploy this on a live system*]

You can start with this sample `docker-compose.yml` file:
```yaml
services:
  [*PROJECT*]:
    image: [*IMAGE_NAME*]
    deploy:
    networks:
    ports:
    secrets:
    ulimits:
    volumes:
    environment:
```

## Authors

* [*AUTHOR*](https://github.com/[*AUTHOR*]) - Initial work.

See also the list of
[contributors](https://github.com/[*AUTHOR*]/[*REPOSITORY*]/contributors)
who participated in this project.

## License

This project is licensed under the Apache License, Version 2.0 - see the
[LICENSE](LICENSE) file for details.

## Acknowledgments

[*Hat tip to anyone who's code or inspiration was used*]
