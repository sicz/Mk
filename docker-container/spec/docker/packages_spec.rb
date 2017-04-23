# encoding: UTF-8
require "docker_helper"

describe "Packages" do
  [
    [*INSTALLED PACKAGES*]
  ].each do |package|
    describe package(package) do
      it { should be_installed }
    end
  end
end
