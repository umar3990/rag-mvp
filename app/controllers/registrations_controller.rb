class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @organization = Organization.new
    @user = User.new
  end

  def create
    @organization = Organization.new(organization_params)
    @user = @organization.users.new(user_params)

    if @organization.save
      start_new_session_for @user
      redirect_to after_authentication_url
    else
      # Both may have contributed errors (e.g. duplicate org name, weak
      # password) -- collect the user's errors onto the organization's
      # error object so the one form can display all of them together.
      @user.errors.each { |error| @organization.errors.import(error) }
      render :new, status: :unprocessable_entity
    end
  end

  private
    def organization_params
      params.require(:organization).permit(:name)
    end

    def user_params
      params.require(:user).permit(:email_address, :password, :password_confirmation)
    end
end
