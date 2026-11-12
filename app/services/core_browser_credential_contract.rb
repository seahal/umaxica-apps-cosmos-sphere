# typed: false
# frozen_string_literal: true

# Admission switch for the Core browser's RP cookie API.
module CoreBrowserCredentialContract
  module_function

  def enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("CORE_BROWSER_JWT_COOKIE_ENABLED"))
  end
end
