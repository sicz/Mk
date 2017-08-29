# encoding: UTF-8
require "serverspec"
require "docker"

set :backend, :docker
set :docker_container, ENV["CONTAINER_NAME"]
