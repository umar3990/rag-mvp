require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signing up creates an organization and its first user, then signs them in" do
    assert_difference [ "Organization.count", "User.count" ], 1 do
      post registration_path, params: {
        organization: { name: "New Co" },
        user: { email_address: "founder@newco.com", password: "password123", password_confirmation: "password123" }
      }
    end

    organization = Organization.find_by(name: "New Co")
    user = User.find_by(email_address: "founder@newco.com")
    assert_equal organization, user.organization
    assert_redirected_to root_url

    follow_redirect!
    assert_response :success
  end

  test "rejects mismatched password confirmation without creating records" do
    assert_no_difference [ "Organization.count", "User.count" ] do
      post registration_path, params: {
        organization: { name: "New Co" },
        user: { email_address: "founder@newco.com", password: "password123", password_confirmation: "nope" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "rejects a duplicate organization name" do
    assert_no_difference [ "Organization.count", "User.count" ] do
      post registration_path, params: {
        organization: { name: organizations(:one).name },
        user: { email_address: "someone@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_response :unprocessable_entity
  end
end
