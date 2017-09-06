# A build tool for the Docker images

[![CircleCI](https://circleci.com/gh/sicz/Mk.svg?style=shield&circle-token=d1b3c54fc08a17aca43ca02ad8ab8ecff230b417)](https://circleci.com/gh/sicz/Mk)

**This project is not aimed at public consumption.
It exists to support the development of SICZ containers.**

Makefiles supporting Docker image development.

## Getting started

These instructions will get you a copy of the project up and running on your
local machine for development and testing purposes.

### Prerequisities

You should have GNU make installed.

### Installing

Clone GitHub repository to your working directory:
```bash
git clone https://github.com/sicz/Mk
```

### Usage

Create a new Docker image directory:
```bash
make create NAME=my-docker-image
```

Read carefully and adjust all files in your new Docker image directory.

## Authors

* [Petr Řehoř](https://github.com/prehor) - Initial work.

See also the list of [contributors](https://github.com/sicz/Mk/contributors)
who participated in this project.

## License

This project is licensed under the Apache License, Version 2.0 - see the
[LICENSE](LICENSE) file for details.
