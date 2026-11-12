# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Concerns
  class ApplicationControllerCommonPatternsTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    ALL_CONTROLLER_FILES = Dir.glob(Rails.root.join("app/controllers/**/application_controller.rb").to_s)
      .reject { |f| f.include?("/vendor/") }
      .reject { |f| f.end_with?("/controllers/application_controller.rb") }
      .reject { |f| f.include?("/sign/com/") }
      .reject { |f| f.include?("/jump/") }
      .sort
    CONTROLLER_FILES =
      ALL_CONTROLLER_FILES.index_with do |file|
        {
          content: File.read(file),
          name: file.gsub(Rails.root.join("app/controllers/").to_s, "")
            .gsub("/application_controller.rb", "")
            .gsub("/", "::")
            .gsub("_", " ")
            .split.map(&:capitalize).join("::"),
          path_name: file.gsub(Rails.root.join("app/controllers/").to_s, "")
            .gsub("/application_controller.rb", "")
            .gsub("/", "::"),
        }
      end

    test "all application controllers include RateLimit" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert_includes content, "RateLimit",
                        "#{controller_name} should include RateLimit"
      end
    end

    test "all application controllers include an actor lifecycle" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:name]

        assert(
          content.include?("ActorSupport") || content.include?("ComAnonymousActorContext"),
          "#{controller_name} should include ActorSupport or ComAnonymousActorContext",
        )
      end
    end

    test "all application controllers have cleanup action" do
      pattern = %r{
        (after_action|append_after_action)\s+:(purge_current|finish_request)
        |
        (prepend_around_action|around_action)\s+:(with_actor_lifecycle|with_anonymous_context_lifecycle)
    }x

      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_match(
          pattern,
          content,
          "#{controller_name} should have cleanup action",
        )
      end
    end

    test "application controllers do not register removed default rate limit callback" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        assert_not_includes content, "before_action :check_default_rate_limit",
                            "#{controller_name} should not use removed default rate limit callback"
      end
    end

    # The com realm was retired (WU-4); no application controller may reintroduce a visitor
    # credential boundary. This is the wedge guarding against its return.
    test "no application controller authenticates a visitor" do
      CONTROLLER_FILES.each_value do |controller|
        assert_not_includes controller[:content], "AuthenticationVisitor",
                            "#{controller[:path_name]} must not authenticate a visitor"
      end
    end

    test "application controllers with OIDC include OidcSsoInitiator" do
      CONTROLLER_FILES.each_value do |controller|
        content = controller[:content]
        controller_name = controller[:path_name]

        if content.include?("oidc_client_id")
          assert_includes content, "OidcSsoInitiator",
                          "#{controller_name} with oidc_client_id should include OidcSsoInitiator"
        end
      end
    end
  end
end
