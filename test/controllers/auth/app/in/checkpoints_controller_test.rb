# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class Auth::App::Sign::In::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_tokens

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
  end

  test "checkpoint and OIDC handoff refuse an actor blocked after successful email OTP authentication" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    visa_host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
    jump = Rails.configuration.x.boot_config.fetch(:jump)
    jump_host = URI.parse(jump.origin.to_s).host
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER, birthdate: Date.new(2000, 1, 1),
    )
    address = "sequence-blocked-#{SecureRandom.hex(8)}@example.test"
    contact = actor.client_emails.create!(
      address:, confirm_policy: "1", user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    contact.finalize_binding!
    browser = open_session
    browser.host!(base_host)
    browser.https!
    navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    browser.get(base_app_sign_show_path(ri: "jp"), headers: navigation)

    assert_equal 200, browser.response.status
    form = browser.response.parsed_body.at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    browser.post(
      form["action"], params: fields,
                      headers: { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" },
    )

    assert_equal 303, browser.response.status
    current_host = base_host
    entry_ref = nil
    20.times do
      if browser.response.redirect?
        target = URI.parse(browser.response.location)
        target = URI.parse("https://#{current_host}#{target}") unless target.host
        if target.host == jump_host
          rt = Rack::Utils.parse_nested_query(target.query).fetch("rt")
          namespace = { base_host => "BASE_APP", visa_host => "VISA_APP", auth_host => "AUTH_APP" }.fetch(current_host)
          issuer = JitSecurityJwtRegistry.surface(namespace)
          payload, = JWT.decode(
            rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{current_host}",
            verify_aud: true, aud: jump.audience,
          )
          target = URI.parse(payload.fetch("url"))
        end

        assert_equal "https", target.scheme
        assert_includes [base_host, visa_host, auth_host], target.host
        entry_ref ||= Rack::Utils.parse_nested_query(target.query.to_s)["entry_ref"]
        browser.host!(target.host)
        browser.get(target.request_uri, headers: navigation.merge("Sec-Fetch-Site" => "cross-site"))
        current_host = target.host
        next
      end

      confirmation = browser.response.parsed_body.at_css("form#base-ceremony-binding-confirmation-form")
      break unless confirmation

      fields = confirmation.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      browser.post(
        confirmation["action"],
        params: fields,
        headers: navigation.merge("Origin" => "https://#{current_host}", "Sec-Fetch-Site" => "same-origin"),
      )
    end

    assert_equal auth_host, browser.host
    assert_equal 200, browser.response.status
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref:)
    ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)

    assert_predicate ceremony, :admitted?
    browser.get(new_auth_app_sign_in_email_path(ri: "jp"), headers: navigation)

    assert_equal 200, browser.response.status
    csrf_meta = browser.response.parsed_body.at_css('meta[name="csrf-token"]')
    request_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
    request_headers["X-CSRF-Token"] = csrf_meta["content"] if csrf_meta
    job_cursor = ActiveJob::Base.queue_adapter.enqueued_jobs.length
    delivery_cursor = ActionMailer::Base.deliveries.length
    TurnstileVerifierStub.stub(:verify, { "success" => true }) do
      browser.post(
        auth_app_sign_in_email_path(ri: "jp"),
        params: { :client_email => { address: }, "cf-turnstile-response" => "provider-response" },
        headers: request_headers,
      )

      assert_equal 302, browser.response.status
      10.times do
        queued = ActiveJob::Base.queue_adapter.enqueued_jobs
        break if job_cursor >= queued.length

        ActiveJob::Base.execute(queued.fetch(job_cursor))
        job_cursor += 1
      end
      delivered = ActionMailer::Base.deliveries.drop(delivery_cursor).find { |mail| mail.to == [address] }

      assert delivered, "The actual sign-in OTP must be delivered to the owning email"
      match = delivered.text_part.body.decoded.match(/Pass Code:\s*([0-9]{6})/)

      assert match, "The delivered sign-in message must contain a code"
      code = match[1]
      browser.get(URI.parse(browser.response.location).request_uri, headers: navigation)

      assert_equal 200, browser.response.status
      csrf_meta = browser.response.parsed_body.at_css('meta[name="csrf-token"]')
      request_headers["X-CSRF-Token"] = csrf_meta["content"] if csrf_meta
      browser.patch(
        auth_app_sign_in_email_path(ri: "jp"),
        params: { :client_email => { pass_code: code }, "cf-turnstile-response" => "provider-response" },
        headers: request_headers,
      )
    end

    assert_includes [302, 303], browser.response.status
    flow = ClientSignInFlow.find_by!(principal_id: actor.id)

    assert_predicate flow.authentication_event_at, :present?
    assert_predicate ceremony.reload, :authentication_evidence_recorded?
    assert flow.sign_in_checkpoint_pending? || flow.sign_in_selector_pending? || flow.sign_in_session_issuance_pending?,
           "The real OTP must advance the flow to the result-handoff boundary"
    assert_equal 0, ClientToken.where(user_id: actor.id).count
    state = flow.state_id
    actor.reload.update!(status_id: ClientStatus::RESERVED)

    assert_not_predicate actor, :login_allowed?
    [auth_app_sign_in_check_path(ri: "jp"), auth_app_sign_oidc_handoff_path(ri: "jp")].each do |path|
      browser.get(path, headers: navigation)

      assert_equal 400, browser.response.status
      assert_nil browser.response.headers["Location"]
      assert_equal 0, ClientToken.where(user_id: actor.id).count
      assert_equal state, flow.reload.state_id
      assert_equal 0, ClientAuthAdmissionBinding.where(
        authorization_transaction_id: binding.authorization_transaction_id, purpose: "authentication_result",
      ).count
    end
  end

  test "show without admission refuses to establish an Auth ceremony" do
    get auth_app_sign_in_check_url(ri: "jp"), headers: host_headers(@host)

    assert_response :bad_request
    assert_nil response.headers["Location"]
  end

  test "show without sign in sequence is rejected" do
    get auth_app_sign_in_check_url(ri: "jp"),
        headers: as_user_headers(@user, host: @host)

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.not_authorized")
  end

  test "update is not routed" do
    patch auth_app_sign_in_check_url(ri: "jp"),
          headers: as_user_headers(@user, host: @host).merge(
            "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new"),
          )

    assert_response :not_found
  end

  test "destroy is not routed" do
    pt = Base64.urlsafe_encode64("/settings")

    delete auth_app_sign_in_check_url(ri: "jp", pt: pt),
           headers: as_user_headers(@user, host: @host).merge(
             "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "updated"),
           )

    assert_response :not_found
  end

  private

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
  end
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::Sign::In::CheckpointsControllerTest
  private

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end
