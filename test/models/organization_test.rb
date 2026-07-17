require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "requires a name" do
    organization = Organization.new
    assert_not organization.valid?
    assert_includes organization.errors[:name], "can't be blank"
  end

  test "requires a unique name" do
    organization = Organization.new(name: organizations(:one).name)
    assert_not organization.valid?
    assert_includes organization.errors[:name], "has already been taken"
  end

  test "deleting an organization with users is restricted" do
    assert_no_difference "Organization.count" do
      organizations(:one).destroy
    end
    assert_includes organizations(:one).errors[:base], "Cannot delete record because dependent users exist"
  end

  test "generates a unique webhook token on create" do
    organization = Organization.create!(name: "New Co")
    assert organization.webhook_token.present?
    assert_not_equal organizations(:one).webhook_token, organization.webhook_token
  end
end
