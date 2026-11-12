# frozen_string_literal: true

if ENV["COVERAGE"] == "true"
  # `require "simplecov"` already loads ./.simplecov, and that file loads the
  # "rails" profile along with the rest of the configuration. Passing the
  # profile to `start` as well would apply it a second time (only duplicating
  # filters, but splitting the configuration across two places). Keep .simplecov
  # as the single source of configuration and let `start` just begin tracking.
  require "simplecov"
  SimpleCov.start
end

ENV["RAILS_ENV"] ||= "test"
# Host names are deliberately NOT set here. This file is read after the application has
# already booted whenever the runner boots first (`bin/rails test` with no path argument,
# which is the documented command), and config/application.rb freezes
# Rails.configuration.x.boot_config from ENV at boot. An assignment made here therefore
# reaches ENV but never boot_config, leaving two disagreeing sources of truth for the same
# host and making results depend on how the suite was invoked. Host configuration belongs
# to the process environment (compose.yaml, the CI job env), which is set before boot.
# test/config/host_configuration_consistency_test.rb fails loudly if the two ever diverge.
ENV["SMTP_FROM_ADDRESS_APP"] = "from@umaxica.app"
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)

require_relative "../config/environment"

# Build the test-mode Vite assets before anything renders a view.
#
# `config/vite.json` sets `"autoBuild": false` for test, and `/public/vite*` is gitignored, so
# nothing else in the repository guarantees that `public/vite-test` exists or is current. Every
# layout under `app/views/layouts` calls `vite_stylesheet_tag`/`vite_typescript_tag`, and
# `ViteRuby::Manifest#lookup!` raises from inside view rendering when an entry is absent, so a
# fresh checkout, a CI runner, or a run made after editing `src/` failed with an error naming an
# entrypoint instead of the missing build. Building here keeps that dependency explicit and
# satisfied in every environment.
#
# Placement matters: this runs in the parent process, before
# `ActiveSupport::TestCase.parallelize` forks workers, so one build serves the whole run instead
# of every worker racing to write the same output directory. `ViteRuby::Builder#build` compares a
# digest of the watched files against `tmp/cache/vite/last-build-test.json` and skips the Vite
# call when nothing changed, so a repeat run pays only for the digest.
unless ViteRuby.commands.build
  abort <<~MESSAGE
    Vite test-mode build failed, so public/vite-test has no usable manifest and every test that
    renders a layout would fail on a missing entrypoint. See the Vite output above; the same build
    runs standalone as `bunx vite build --mode test`.
  MESSAGE
end

require "rails/test_help"
# `Minitest.load(:test_prof)` only requires the Minitest reporter shims
# (`lib/minitest/test_prof_plugin.rb`); it does not load the TestProf recipe classes
# (`TestProf::EventProf`, `TestProf::StackProf`, `TestProf::MinitestSample`, ...), which live
# behind the gem's top-level `require "test_prof"` entrypoint. Loading them here only defines
# classes and registers `TestProf.activate` hooks that stay inert unless their env var
# (`EVENT_PROF`, `TEST_STACK_PROF`, `SAMPLE`, ...) is set, so this carries no cost for an
# ordinary `bin/rails test` run.
require "test_prof"
Minitest.load(:test_prof)
# `MinitestSample` (backs `SAMPLE`/`SAMPLE_GROUPS`) is a recipe, not part of the top-level
# `test_prof` require above, and must be loaded explicitly like any other TestProf recipe.
require "test_prof/recipes/minitest/sample"
require_relative "support/parallel_test_database_cloner"
require_relative "support/form_action_policy_helper"
require_relative "support/fetch_metadata_defaults"
require_relative "support/outbound_http_guard"
require_relative "support/outbound_http_stub"
require_relative "support/valkey_test_isolation"
require_relative "support/set_cookie_assertions"
require_relative "support/withheld_assertions"
require_relative "support/cookie_jar_helper"
require_relative "support/inertia_page_object"
require_relative "support/strict_loading_association_preloader"
require_relative "support/public_id_fixed_length_assertions"

module ActiveSupport
  class TestCase
    include WithheldAssertions
    include CookieJarHelper
    include FormActionPolicyHelper
    include OutboundHttpStub
    include PublicIdFixedLengthAssertions

    # Physical cores, not logical processors (SMT/vCPUs): measured on a 16-core/32-thread host --
    # `PARALLEL_WORKERS=32` (one per logical thread) took 37s on a 3000-test subset versus 22-24s
    # at 8 or 16 workers, because that many forked Rails processes plus Postgres itself oversubscribe
    # the physical cores and thrash instead of parallelizing further. See
    # docs/guides/test-profiling.md.
    #
    # A coverage run uses the same workers as any other run. `.simplecov` sets
    # `merge_subprocesses true`, so SimpleCov hooks `Process._fork` and each worker records and
    # writes its own resultset for the parent to merge; before that setting existed the run had to
    # be pinned to a single worker or the forked workers' coverage was lost.
    parallel_workers = Integer(ENV.fetch("PARALLEL_WORKERS") { Concurrent.physical_processor_count.to_s }, 10)
    raise ArgumentError, "PARALLEL_WORKERS must be positive" unless parallel_workers.positive?

    fixtures :all
    ValkeyTestIsolation.install!
    ParallelTestDatabaseCloner.install!(workers: parallel_workers)
    parallelize(workers: parallel_workers, parallelize_databases: false)

    # Rate-limit uses KVS Valkey namespaced by run and worker. Reset the store
    # and delete this worker's keys so counters do not leak into the next case.
    setup do
      Rails.configuration.x.rate_limit.fetch(:store).reset!
      Rails.cache.clear
      ValkeyTestIsolation.cleanup_worker_keys!
    end

    # Every retained host begins available; a test that exercises an unavailable host
    # disables only the matching slot.
    setup do
      FqdnAvailabilityRegistry.flag_names.each { |feature| Flipper.enable(feature) }
    end

    # I18n.locale is thread-local and is set by controller `set_locale`
    # before_actions during integration/controller tests. Those tests share
    # worker processes with model tests, so a request that leaves I18n.locale
    # at, e.g., :en would make a later model test read English validation
    # messages where it expects the default locale. Reset to the default after
    # every test so locale never leaks across the shared process.
    teardown { I18n.locale = I18n.default_locale } # rubocop:disable Rails/I18nLocaleAssignment

    # ENV is process-global and shared by every test a worker runs. Many integration helpers
    # (load_jump_rt_env!) write JWT_<NAMESPACE>_* without restoring them, and the local keyset
    # installer rejects such values, so a later test failed depending on seed order. Snapshot
    # ENV before each test and restore it afterwards so no assignment outlives its test.
    setup { @env_snapshot_before_test = ENV.to_h }
    teardown { ENV.replace(@env_snapshot_before_test) if @env_snapshot_before_test }
  end
end
