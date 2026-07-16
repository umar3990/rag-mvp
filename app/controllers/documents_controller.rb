class DocumentsController < ApplicationController
  before_action :set_document, only: %i[ show ]

  def index
    @documents = current_organization.documents.order(created_at: :desc)
  end

  def new
    @document = current_organization.documents.new
  end

  def create
    @document = current_organization.documents.new(document_params)
    @document.user = Current.session.user

    if @document.save
      redirect_to documents_path, notice: "Document uploaded — processing in the background."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  private
    def current_organization
      Current.session.user.organization
    end

    def set_document
      @document = current_organization.documents.find(params[:id])
    end

    def document_params
      params.require(:document).permit(:title, :file)
    end
end
