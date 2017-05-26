# encoding: UTF-8
require "docker_helper"

describe "Package" do
  [
    [*INSTALLED PACKAGES*]
  ].each do |package|
    context package do
      it "is installed" do
        expect(package(package)).to be_installed
      end
    end
  end
end
