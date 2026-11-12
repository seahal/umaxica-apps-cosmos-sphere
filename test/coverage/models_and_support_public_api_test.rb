# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorPublicApiCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup { Actor.reset }
  teardown { Actor.reset }

  test "channel and transport readers preserve their independent installed values" do
    Actor.install_context!(channel: :browser, transport: :cookie)

    assert_equal :browser, Actor.channel
    assert_equal :cookie, Actor.transport
    assert_predicate Actor, :browser?
    assert_predicate Actor, :cookie?
  end

  test "signed_up distinguishes unauthenticated, identifier-only, and persisted actors" do
    Actor.actor = Struct.new(:id).new("actor-1")

    assert_not_predicate Actor, :signed_up?

    Actor.actor_type = :client

    assert_predicate Actor, :signed_up?

    Actor.actor = Struct.new(:id, :persisted?).new(nil, true)

    assert_predicate Actor, :signed_up?

    Actor.actor = Object.new

    assert_not_predicate Actor, :signed_up?
  end

  test "authentication exposes public null verified and standby predicates" do
    assert_predicate Actor::Authentication::NULL, :null?
    assert_not_predicate Actor::Authentication.new(access_claims: { "sub" => "subject" }), :null?
    assert_not_predicate Actor::Authentication::NULL, :verified?
    assert_predicate Actor::Authentication.new(amr: ["passkey"]), :verified?
    assert_predicate Actor::Authentication.new(acr: "aal1"), :verified?

    standby = Actor::Authentication.new(access_claims: { "authn_ctx" => "standby" })

    assert_predicate standby, :standby?
  end

  test "configuration and step-up null values expose their public state predicates" do
    assert_not_predicate Actor::Configuration::NULL_VALUE, :configured?
    assert_predicate Actor::StepUp.null, :null?
    assert_not_predicate Actor::StepUp.null, :usable_token?
    assert_predicate Actor::StepUp.null.with(usable_token: true), :usable_token?
  end
end

class ChronicleReferencePublicApiCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "public defaults entry points preserve fixed event and level identifiers" do
    reference_models = [
      AppPreferenceChronicleEvent,
      OrgPreferenceChronicleEvent,
      ComPreferenceChronicleEvent,
      ComPreferenceChronicleLevel,
    ]

    reference_models.each do |model|
      model.ensure_defaults!

      assert_empty model::DEFAULTS - model.pluck(:id)
    end

    ApplicationRecord.clear_fixed_id_seed_cache!
  end

  test "public fixed-id insertion accepts an empty list and an absent table" do
    assert_nil ClientChronicleEvent.insert_missing_fixed_ids!([])
    assert_nil ApplicationRecord.insert_missing_fixed_ids!([2_000_000_001])
  end

  test "public fixed-id insertion restores a missing identifier on its writer database" do
    model = ClientChronicleEvent
    identifier = 2_000_000_001

    model.transaction(requires_new: true) do
      assert_not model.exists?(id: identifier)

      model.insert_missing_fixed_ids!([identifier])

      assert model.exists?(id: identifier)
      raise ActiveRecord::Rollback
    end

    assert_not model.exists?(id: identifier)
  ensure
    ApplicationRecord.clear_fixed_id_seed_cache!
  end
end

class PersistedModelPublicApiCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "public URL parameter uses the opaque identifier" do
    principal = RpCoreAppPrincipal.new(public_id: "public-principal-reference")

    assert_equal "public-principal-reference", principal.to_param
  end

  test "public local principal state reflects its disablement timestamp" do
    principal = RpCoreAppPrincipal.new

    assert_not_predicate principal, :deactivated?

    principal.disabled_at = Time.utc(2026, 1, 2, 3, 4, 5)

    assert_predicate principal, :deactivated?
  end
end

class ApplicationErrorPublicApiCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "application error with no translation key has an empty standard message" do
    error = ApplicationError.new

    assert_equal "ApplicationError", error.message
    assert_nil error.i18n_key
    assert_empty error.context
  end

  test "blank public identifier error exposes its record class and explicit message" do
    error = BlankPublicIdentifierError.new(record_class: RpCoreAppPrincipal)

    assert_equal "RpCoreAppPrincipal", error.record_class
    assert_equal :internal_server_error, error.status_code
    assert_equal({ record_class: "RpCoreAppPrincipal" }, error.context)
    assert_equal "RpCoreAppPrincipal has a blank public_id and cannot be exposed to a client", error.message
  end
end

class ApplicationHelperPublicApiCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "brand TLD is normalized from a supported request host" do
    helper = ApplicationController.helpers
    request = ActionDispatch::TestRequest.create
    request.host = "WWW-JP.UMAXICA.APP"

    helper.stub(:request, request) do
      assert_equal "APP", helper.brand_tld
    end
  end

  test "brand TLD refuses a host outside the supported labels" do
    helper = ApplicationController.helpers
    request = ActionDispatch::TestRequest.create
    request.host = "localhost"

    helper.stub(:request, request) do
      assert_raises(ArgumentError) { helper.brand_tld }
    end
  end
end

class CspViolationSubscriberPublicApiCoverageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "public emit logs the accepted event through the application event formatter" do
    messages = []
    event = { name: "security.csp_violation", payload: { surface: "core/app" } }

    Rails.logger.stub(:info, ->(message) { messages << message }) do
      CspViolationSubscriber.new.emit(event)
    end

    assert_equal 1, messages.length
    record = JSON.parse(messages.fetch(0))

    assert_equal "security.csp_violation", record.fetch("event")
    assert_equal({ "surface" => "core/app" }, record.fetch("data"))
  end

  test "public emit reports formatter failures without raising to the notification caller" do
    messages = []

    Rails.logger.stub(:error, ->(message) { messages << message }) do
      CspViolationSubscriber.new.emit(name: "security.csp_violation")
    end

    assert_equal 1, messages.length
    record = JSON.parse(messages.fetch(0))

    assert_equal CspViolationSubscriber::FAILURE_EVENT_NAME, record.fetch("event")
    assert_equal "KeyError", record.dig("data", "error_class")
  end
end
