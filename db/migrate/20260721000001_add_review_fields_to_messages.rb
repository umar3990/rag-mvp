class AddReviewFieldsToMessages < ActiveRecord::Migration[8.1]
  def change
    # Nullable on purpose -- review only applies to email-sourced
    # assistant replies. Web-sourced chat replies show directly to the
    # internal user asking, so they never enter a review_status at all.
    add_column :messages, :review_status, :string
    add_reference :messages, :reviewed_by, foreign_key: { to_table: :users }, null: true
    add_column :messages, :reviewed_at, :datetime
  end
end
