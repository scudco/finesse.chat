Rails.application.config.after_initialize do
  SolidQueue::Record.strict_loading_by_default = false
end
