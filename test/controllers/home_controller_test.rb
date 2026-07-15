require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index when signed in" do
    sign_in_as users(:one)

    get root_url
    assert_response :success
  end

  test "redirects to sign in when not authenticated" do
    get root_url
    assert_redirected_to new_session_path
  end
end
