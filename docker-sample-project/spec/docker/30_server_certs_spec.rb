require "docker_helper"

### SERVER_CERTIFICATE #########################################################

describe "Server certificate", :test => :server_cert do
  # Default Serverspec backend
  before(:each) { set :backend, :docker }

  ### CONFIG ###################################################################

  user = "root"
  group = "root"

  crt = ENV["SERVER_CRT_FILE"]      || "/etc/ssl/certs/server.crt"
  key = ENV["SERVER_KEY_FILE"]      || "/etc/ssl/private/server.key"
  pwd = ENV["SERVER_KEY_PWD_FILE"]  || "/etc/ssl/private/server.pwd"

  subj = ENV["SERVER_CRT_SUBJECT"]  || "CN=#{ENV["CONTAINER_NAME"]}"

  ### CERTIFICATE ##############################################################

  describe x509_certificate(crt) do
    context "file" do
      subject { file(crt) }
      it { is_expected.to be_file }
      it { is_expected.to be_mode(444) }
      it { is_expected.to be_owned_by(user) }
      it { is_expected.to be_grouped_into(group) }
    end
    context "certificate" do
      it { is_expected.to be_certificate }
      it { is_expected.to be_valid }
    end
    its(:subject) { is_expected.to eq "/#{subj}" }
    its(:issuer)  { is_expected.to eq "/CN=Simple CA" }
    its(:validity_in_days) { is_expected.to be > 3650 }
    context "subject_alt_names" do
      it { expect(subject.subject_alt_names).to include("DNS:#{ENV["SERVER_CRT_HOST"]}") } unless ENV["SERVER_CRT_HOST"].nil?
      it { expect(subject.subject_alt_names).to include("DNS:#{ENV["CONTAINER_NAME"]}") }
      it { expect(subject.subject_alt_names).to include("DNS:localhost") }
      it { expect(subject.subject_alt_names).to include("IP Address:#{ENV["SERVER_CRT_IP"]}") } unless ENV["SERVER_CRT_IP"].nil?
      it { expect(subject.subject_alt_names).to include("IP Address:127.0.0.1") }
      it { expect(subject.subject_alt_names).to include("Registered ID:#{ENV["SERVER_CRT_OID"]}") } unless ENV["SERVER_CRT_OID"].nil?
    end
  end

  ### PRIVATE_KEY_PASSPHRASE ###################################################

  describe "X509 private key passphrase \"#{pwd}\"" do
    context "file" do
      subject { file(pwd) }
      it { is_expected.to be_file }
      it { is_expected.to be_mode(440) }
      if ENV["DOCKER_CONFIG"] == "custom" then
        it { is_expected.to be_owned_by(user) }
        it { is_expected.to be_grouped_into(group) }
      end
    end
  end

  ### PRIVATE_KEY ##############################################################

  describe x509_private_key(key, {:passin => "file:#{pwd}"}) do
    context "file" do
      subject { file(key) }
      it { is_expected.to be_file }
      it { is_expected.to be_mode(440) }
      it { is_expected.to be_owned_by(user) }
      it { is_expected.to be_grouped_into(group) }
    end
    context "key" do
      it { is_expected.to be_encrypted }
      it { is_expected.to be_valid }
      it { is_expected.to have_matching_certificate(crt) }
    end
  end

  ##############################################################################

end

################################################################################
