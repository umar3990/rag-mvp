class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.references :organization, null: false, foreign_key: true
      # Nullable: the uploader is audit metadata, not a hard requirement --
      # a document should survive its uploader's account being deleted.
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
  end
end
