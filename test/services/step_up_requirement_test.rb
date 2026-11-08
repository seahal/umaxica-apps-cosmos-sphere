# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StepUpRequirementTest < ActiveSupport::TestCase
  test "build rejects a legacy AAL demand instead of translating it" do
    assert_raises(ArgumentError) do
      StepUpRequirement.build(
        {
          step_up_required: true,
          required_aal: "aal2",
          phishing_resistant_required: false,
          user_verification_required: false,
          full_reauthentication_required: false,
          allowed_methods: [:passkey],
          ttl: 15.minutes,
          scope: "profile",
          purpose: "step_up",
          audience: "step_up:app",
          session_binding: "session-1",
          token_binding: "token-1",
          require_session_binding: true,
          actor_ref: "actor-1",
          resource_ref: nil,
          tenant_ref: nil,
        },
      )
    end
  end

  test "build requires the complete explicit contract" do
    assert_raises(ArgumentError) do
      StepUpRequirement.build(nil, scope: "profile")
    end
  end

  test "normal step up keeps freshness separate from assurance" do
    requirement = StepUpRequirement.new(
      step_up_required: true,
      scope: "profile",
      required_aal: nil,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      allowed_methods: %i(passkey totp email_otp),
      ttl: 15.minutes,
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    )

    assert_predicate requirement, :step_up_required?
    assert_nil requirement.required_aal
    assert_not_predicate requirement, :aal_required?
    assert_not_predicate requirement, :phishing_resistant_required?
    assert requirement.method_allowed?(:email_otp)
  end

  test "high assurance conditions remain independently expressible" do
    requirement = StepUpRequirement.new(
      step_up_required: true,
      scope: "profile",
      phishing_resistant_required: true,
      user_verification_required: true,
      full_reauthentication_required: false,
      allowed_methods: [:passkey],
      ttl: 15.minutes,
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    )

    assert_predicate requirement, :phishing_resistant_required?
    assert_predicate requirement, :user_verification_required?
    assert_not_predicate requirement, :full_reauthentication_required?
    assert_equal "actor-1", requirement.actor_ref
    assert_nil requirement.resource_ref
    assert_nil requirement.tenant_ref
  end

  test "required requirements reject omitted mandatory booleans and bindings" do
    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        scope: "profile", allowed_methods: [:passkey], ttl: 15.minutes,
        purpose: "step_up", audience: "step_up:app", session_binding: "session-1",
        token_binding: "token-1", require_session_binding: true, actor_ref: "actor-1",
        resource_ref: nil, tenant_ref: nil,
      )
    end

    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        scope: "profile", phishing_resistant_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        allowed_methods: [:passkey], ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:app", session_binding: "session-1", token_binding: "token-1",
        require_session_binding: true, actor_ref: nil, resource_ref: nil, tenant_ref: nil,
      )
    end
  end

  test "boolean values are strict and unsupported legacy AAL demands are refused" do
    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        step_up_required: "false", phishing_resistant_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        allowed_methods: [], ttl: 15.minutes, scope: nil, purpose: nil, audience: nil,
        session_binding: nil, token_binding: nil, require_session_binding: false,
        actor_ref: nil, resource_ref: nil, tenant_ref: nil,
      )
    end

    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        required_aal: :aal2, scope: "profile", phishing_resistant_required: false,
        user_verification_required: false, full_reauthentication_required: false,
        allowed_methods: [:passkey], ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:app", session_binding: "session-1", token_binding: "token-1",
        require_session_binding: true, actor_ref: "actor-1", resource_ref: nil, tenant_ref: nil,
      )
    end
  end

  test "disabled requirements cannot carry step-up-only properties" do
    requirement = StepUpRequirement.new(step_up_required: false)

    assert_not_predicate requirement, :step_up_required?
    assert_equal({ step_up_required: false }, requirement.to_h)
    assert_equal requirement.to_h, StepUpRequirement.build(requirement.to_h).to_h
    assert_equal requirement.to_h, StepUpRequirement.build(step_up_required: false).to_h
    assert_not requirement.method_allowed?(:passkey)
    assert_predicate requirement, :frozen?

    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        step_up_required: false, phishing_resistant_required: true,
        user_verification_required: false, full_reauthentication_required: false,
        allowed_methods: [:passkey], ttl: 15.minutes, scope: "profile",
        purpose: "step_up", audience: "step_up:app", session_binding: "session-1",
        token_binding: "token-1", require_session_binding: true, actor_ref: "actor-1",
        resource_ref: nil, tenant_ref: nil,
      )
    end
  end

  test "disabled requirements reject explicitly supplied properties including nil false and empty values" do
    {
      required_aal: nil,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      allowed_methods: [],
      ttl: nil,
      scope: nil,
      purpose: nil,
      audience: nil,
      session_binding: nil,
      token_binding: nil,
      require_session_binding: false,
      actor_ref: nil,
      resource_ref: nil,
      tenant_ref: nil,
    }.each do |field, value|
      assert_raises(StepUpRequirement::Invalid, field.to_s) do
        StepUpRequirement.new(**{ :step_up_required => false, field => value })
      end
    end
  end

  test "disabled requirement rejects missing and nonboolean required flags" do
    assert_raises(StepUpRequirement::Invalid) { StepUpRequirement.new }
    [nil, "", "false", 0, [], {}].each do |value|
      assert_raises(StepUpRequirement::Invalid) { StepUpRequirement.new(step_up_required: value) }
    end
  end

  test "build accepts a scope with explicit attributes and preserves an existing requirement" do
    attributes = {
      step_up_required: true,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      allowed_methods: ["PASSKEY", :passkey, "TOTP"],
      ttl: 1,
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    }

    requirement = StepUpRequirement.build(:profile, **attributes)

    assert_equal "profile", requirement.scope
    assert_equal %i(passkey totp), requirement.allowed_methods
    assert_predicate requirement.allowed_methods, :frozen?
    assert_predicate requirement, :frozen?
    assert_same requirement, StepUpRequirement.build(requirement)
    assert_equal attributes.merge(scope: "profile", allowed_methods: %i(passkey totp)), requirement.to_h
    assert_equal requirement.to_h, StepUpRequirement.build(requirement.to_h.stringify_keys).to_h
    [:passkey, "PASSKEY", :totp].each { |method| assert requirement.method_allowed?(method) }
    [nil, "", " ", :password, :email_otp, :secret_credential].each do |method|
      assert_not requirement.method_allowed?(method), method.inspect
    end
  end

  test "requirements reject incompatible purposes assurance methods and session binding" do
    attributes = {
      step_up_required: true,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      allowed_methods: [:totp],
      ttl: 1,
      scope: "profile",
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    }
    [
      [{ purpose: "unsupported" }, "purpose is invalid"],
      [{ full_reauthentication_required: true }, "full reauthentication requires the reauthentication purpose"],
      [{ purpose: "reauthentication" }, "reauthentication requires full_reauthentication_required"],
      [{ phishing_resistant_required: true }, "phishing resistance requires an allowed passkey method"],
      [{ user_verification_required: true }, "user verification requires an allowed passkey method"],
      [{ require_session_binding: false }, "require_session_binding must be true"],
    ].each do |overrides, message|
      error =
        assert_raises(StepUpRequirement::Invalid) do
          StepUpRequirement.new(**attributes.merge(overrides))
        end
      assert_equal message, error.message
    end

    requirement = StepUpRequirement.new(
      **attributes.merge(purpose: "reauthentication", full_reauthentication_required: true),
    )

    assert_predicate requirement, :full_reauthentication_required?
    assert_equal "reauthentication", requirement.purpose
  end

  test "allowed methods reject missing empty and unsupported classifications" do
    attributes = {
      step_up_required: true,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      ttl: 1,
      scope: "profile",
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    }

    [nil, [], "", [nil], [" "], [:password], [:passkey, :password]].each do |methods|
      assert_raises(StepUpRequirement::Invalid, methods.inspect) do
        StepUpRequirement.new(**attributes, allowed_methods: methods)
      end
    end
    StepUpRequirement::METHODS.each do |method|
      requirement = StepUpRequirement.new(**attributes, allowed_methods: method)

      assert_equal [method], requirement.allowed_methods
      assert requirement.method_allowed?(method)
    end
  end

  test "ttl rejects missing nonnumeric nonfinite and nonpositive values and accepts positive numerics" do
    attributes = {
      step_up_required: true,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      allowed_methods: [:passkey],
      scope: "profile",
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    }

    # Integer seconds bracket zero at -1, 0 and 1; a fractional second is also supported.
    [nil, "", "1", -1, 0, Float::INFINITY, -Float::INFINITY, Float::NAN].each do |ttl|
      assert_raises(StepUpRequirement::Invalid, ttl.inspect) do
        StepUpRequirement.new(**attributes, ttl: ttl)
      end
    end
    [1, 0.5].each do |ttl|
      assert_equal ttl, StepUpRequirement.new(**attributes, ttl: ttl).ttl
    end
  end

  test "string fields reject missing blank wrong type and control characters" do
    attributes = {
      step_up_required: true,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      allowed_methods: [:passkey],
      ttl: 1,
      scope: "profile",
      purpose: "step_up",
      audience: "step_up:app",
      session_binding: "session-1",
      token_binding: "token-1",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    }

    %i(scope purpose audience session_binding token_binding actor_ref resource_ref tenant_ref).each do |field|
      ["", " ", 0, [], "value\n", "value\u007f"].each do |value|
        assert_raises(StepUpRequirement::Invalid, "#{field}: #{value.inspect}") do
          StepUpRequirement.new(**attributes.merge(field => value))
        end
      end
    end

    %i(scope purpose audience session_binding token_binding actor_ref).each do |field|
      assert_raises(StepUpRequirement::Invalid, field.to_s) do
        StepUpRequirement.new(**attributes.merge(field => nil))
      end
    end
  end

  test "enabled requirements still require each explicit field after the disabled contract is accepted" do
    attributes = {
      step_up_required: true,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      allowed_methods: [:passkey],
      scope: "settings_passkey",
      session_binding: "session-1",
      token_binding: "session-1",
      ttl: 15.minutes,
      purpose: "step_up",
      audience: "step_up:app",
      require_session_binding: true,
      actor_ref: "actor-1",
      resource_ref: nil,
      tenant_ref: nil,
    }

    assert_predicate StepUpRequirement.new(**attributes), :step_up_required?
    attributes.each_key do |field|
      assert_raises(StepUpRequirement::Invalid, field.to_s) do
        StepUpRequirement.new(**attributes.except(field))
      end
    end
  end
end
