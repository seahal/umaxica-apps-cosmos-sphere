# frozen_string_literal: true

require "test_helper"

class RuntimeValuesRoundThirteenPublicValueObjectContractsTest < ActiveSupport::TestCase
  test "request context exposes the same default region used by normalization" do
    assert_equal RequestContextContract::DEFAULT_REGION, RequestContextContract.default_region
    assert_equal RequestContextContract.default_region, RequestContextContract.normalize_region(nil)
  end

  test "anonymous actor state is the unauthenticated state" do
    context = ActorValuesContext.empty

    assert_predicate context, :anonymous?
    assert_predicate context, :unauthenticated?
    assert_not_predicate context, :authenticated?
  end

  test "authentication context string form is its persisted key" do
    context = AuthenticationContextValue.normal

    assert_equal AuthenticationContextValue::NORMAL_KEY, context.to_s
  end
end
