class AddStatusToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :status, :string, null: false, default: "pending"
  end
end
