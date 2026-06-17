require "rails_helper"

RSpec.describe PortalSession, type: :model do
  let(:account)     { create(:account) }
  let(:integration) { create(:integration, account: account) }
  let(:customer)    { create(:customer, account: account) }

  before { ActsAsTenant.current_tenant = account }

  describe "associations" do
    it { is_expected.to belong_to(:customer) }
    it { is_expected.to belong_to(:integration) }
  end

  describe "validations" do
    subject { build(:portal_session, customer: customer, integration: integration) }
    it { is_expected.to validate_presence_of(:token_digest) }
    it { is_expected.to validate_presence_of(:expires_at) }
    it { is_expected.to validate_uniqueness_of(:token_digest) }
  end

  describe ".generate!" do
    it "creates a session and returns raw token" do
      session, token = described_class.generate!(
        customer:    customer,
        integration: integration
      )

      expect(session).to be_persisted
      expect(token).to be_present
      expect(session.token_digest).to eq(Digest::SHA256.hexdigest(token))
      expect(session.expires_at).to be_within(1.second).of(15.minutes.from_now)
    end
  end

  describe ".find_by_token" do
    it "finds a session by raw token" do
      session, token = described_class.generate!(
        customer:    customer,
        integration: integration
      )

      found = described_class.find_by_token(token)
      expect(found).to eq(session)
    end

    it "returns nil for invalid token" do
      expect(described_class.find_by_token("invalid")).to be_nil
    end

    it "returns nil for blank token" do
      expect(described_class.find_by_token("")).to be_nil
      expect(described_class.find_by_token(nil)).to be_nil
    end
  end

  describe "#expired?" do
    it "returns false when not expired" do
      session, _token = described_class.generate!(
        customer:    customer,
        integration: integration
      )
      expect(session.expired?).to be false
    end

    it "returns true when expired" do
      session, _token = described_class.generate!(
        customer:    customer,
        integration: integration
      )
      session.update_columns(expires_at: 1.minute.ago)
      expect(session.expired?).to be true
    end
  end

  describe "#valid_session?" do
    it "returns true when not expired" do
      session, _token = described_class.generate!(
        customer:    customer,
        integration: integration
      )
      expect(session.valid_session?).to be true
    end
  end

  describe "#touch_access!" do
    it "updates accessed_at and ip_address" do
      session, _token = described_class.generate!(
        customer:    customer,
        integration: integration
      )

      session.touch_access!(ip: "192.168.1.1")
      session.reload

      expect(session.accessed_at).to be_within(1.second).of(Time.current)
      expect(session.ip_address).to eq("192.168.1.1")
    end
  end
end
