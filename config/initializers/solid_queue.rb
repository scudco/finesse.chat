Rails.application.config.to_prepare do
  SolidQueue::Record.strict_loading_by_default = false
end
