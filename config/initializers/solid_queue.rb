Rails.application.config.after_initialize do
  SolidQueue.constants.each do |const|
    klass = SolidQueue.const_get(const)
    klass.strict_loading_by_default = false if klass.is_a?(Class) && klass < ActiveRecord::Base
  rescue NameError
    next
  end
end
