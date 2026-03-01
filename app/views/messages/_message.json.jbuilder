json.extract! message, :id, :content, :author, :created_at, :updated_at
json.url message_url(message, format: :json)
