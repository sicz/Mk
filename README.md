# A build tool for Docker containers

**This project is not aimed at public consumption.
It exists to support the development of SICZ containers.**

Makefiles that support the development of Docker containers.

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

Create new Docker container directory from `docker-container` template directory:
```bash
make create-docker-project NAME=docker-my-container
```

Read carefully and adjust `README.md`, `Makefile`, `LICENSE` and `Dockerfile.tpl`
files in your new Docker container directory . Interesting parts are enclosed in
`[*TEXT*]` brackets.

## Authors

* [Petr Řehoř](https://github.com/prehor) - Initial work.

See also the list of [contributors](https://github.com/sicz/Mk/contributors)
who participated in this project.

## License

This project is licensed under the Apache License, Version 2.0 - see the
[LICENSE](LICENSE) file for details.

<!---
## Acknowledgments

[*Hat tip to anyone who's code or inspiration was used*]
--->
