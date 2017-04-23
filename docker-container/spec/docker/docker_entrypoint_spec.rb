# encoding: UTF-8
require "docker_helper"

describe "Docker Entrypoint" do
  describe file('/docker-entrypoint.sh') do
    it { should be_executable }
  end

  [
    "/docker-entrypoint.d/10-default-command.sh",
  ].each do |file|
    describe file(file) do
      it { should be_file }
    end
  end
end
