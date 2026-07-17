class CreateMessageSources < ActiveRecord::Migration[8.1]
  def change
    create_table :message_sources do |t|
      t.references :message, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end
    add_index :message_sources, [ :message_id, :document_id ], unique: true
  end
end
