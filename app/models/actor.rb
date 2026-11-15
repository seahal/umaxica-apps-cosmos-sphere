# typed: false
# frozen_string_literal: true

# Actor is a request-lifecycle read facade over an already-installed
# ActorValuesContext snapshot.
#
# It is push-based: the controller/authentication pipeline resolves
# authentication, authorization, and step-up, then calls
# Actor.install_context!. Actor never rebuilds auth state from the request and
# never performs token decode, DB lookup, transparent refresh, DPoP/DBSC
# verification or policy-user construction. It is a
# snapshot reader only.
#
# Actor.current / Actor.context return ActorValuesContext.empty when no context
# is installed, so they never raise merely because no request is bound.
class Actor < ActiveSupport::CurrentAttributes
  # Compatibility alias: ActionPolicy (ApplicationPolicy#actor_context) and
  # existing tests reference Actor::Context as the authorization context type.
  # ActorValuesContext is now the canonical class for that context.
  Context = ActorValuesContext

  attribute :context

  resets do
    self.context = ActorValuesContext.empty
  end

  class << self
    CONTEXT_KEY_ALIASES = { actor: :subject }.freeze

    delegate :account, to: :context

    delegate :tenant, to: :context

    delegate :tld, to: :context

    # Route/product surface axis, distinct from tld. See ActorValuesContext.
    delegate :surface, to: :context

    # Credential transport axis (cookie/bearer/none/unknown).
    delegate :transport, to: :context

    # Caller channel axis (browser/native/server/unknown).
    delegate :channel, to: :context

    delegate :trace_id, to: :context

    delegate :span_id, to: :context

    # Role predicates delegate to the installed context. They are role
    # predicates, not authorization gates: protected behavior must still go
    # through ActionPolicy / policy enforcement.
    delegate :client?, :operator?, :unauthenticated?, :authenticated?, to: :context

    # Transport/channel predicates. browser?/native? read channel; cookie?/
    # bearer? read transport. The two axes are not conflated.
    delegate :browser?, :native?, :cookie?, :bearer?, to: :context

    public

    def context
      super || ActorValuesContext.empty
    end

    # The currently installed snapshot, or the empty context when nothing is
    # bound. Safe for bare paths, jobs, mailers, and tests.
    public

    def current = context

    # Push-based lifecycle installer and the only supported write path.
    #
    # Accepts a full ActorValuesContext (positional) or a partial set of
    # attributes (keywords) merged onto the current snapshot. The keyword form
    # preserves the existing incremental-install behavior used across the
    # authentication pipeline. Must stay inside reviewed request lifecycle
    # boundaries (see actor_context_invariant_test).
    public

    def install_context!(context = nil, **attributes)
      if context
        raise ArgumentError, "provide either a context or attributes, not both" if attributes.any?

        self.context = ActorValuesContext.coerce(context)
      else
        update(**attributes)
      end
    end

    public

    def update(**attributes)
      self.context = context.with(**normalize_context_attributes(attributes))
    end

    public

    def clear
      reset
    end

    # Alias for clear, for callers that prefer the reset! spelling.
    public

    def reset! = clear

    public

    def subject = context.subject || Unauthenticated.instance

    # Historical alias for subject, kept for lifecycle and policy compatibility.
    alias_method :actor, :subject

    public

    def subject=(value)
      update(subject: value)
    end

    public

    def actor=(value)
      update(subject: value)
    end

    public

    def actor_type = context.actor_type || :unauthenticated

    public

    def actor_type=(value)
      update(actor_type: value)
    end

    public

    def whoami = actor_type

    public

    def account=(value)
      update(account: value)
    end

    public

    def tenant=(value)
      update(tenant: value)
    end

    public

    def tld=(value)
      update(tld: value)
    end

    public

    def authn = context.authn || Actor::Authentication::NULL

    public

    def authn=(value)
      update(authn: value)
    end

    public

    def authz = context.authz || Actor::Authz::NULL

    public

    def authz=(value)
      update(authz: value)
    end

    public

    def configuration = context.configuration || Actor::Configuration::NULL

    public

    def configuration=(value)
      update(configuration: value)
    end

    public

    def step_up = context.step_up || Actor::StepUp::NULL

    public

    def step_up=(value)
      update(step_up: value)
    end

    public

    def trace_id=(value)
      update(trace_id: value)
    end

    public

    def span_id=(value)
      update(span_id: value)
    end

    alias_method :signed_in?, :authenticated?

    public

    def signed_up?
      return false unless authenticated?
      return true if actor.respond_to?(:persisted?) && actor.persisted?

      actor.respond_to?(:id) && actor.id.present?
    end

    # Spec-facing predicate aliases. The canonical names in this codebase are
    # unauthenticated?/client?/operator?; these mirror the actor-context vocabulary
    # (anonymous/user/staff) without introducing new state.
    public

    def anonymous? = unauthenticated?

    public

    def user? = client?

    public

    def staff? = operator?

    # Freshness comes from the explicit request step_up context.
    public

    def step_up_fresh? = step_up.satisfied?

    # True when the current request demands a step-up that is not yet satisfied.
    # When verification is not required, step_up is Actor::StepUp::NULL (scope nil),
    # so this is false.
    public

    def requires_step_up?
      step_up.scope.present? && !step_up.satisfied?
    end

    public

    def client
      actor if client?
    end

    public

    def operator
      actor if operator?
    end

    private

    # Map legacy attribute keys onto canonical context fields and coerce blank
    # typed sub-values to their NULL objects. Unknown keys (e.g. the removed
    # :authentication / :preference keys) intentionally flow through to
    # Data#with, which raises ArgumentError.
    def normalize_context_attributes(attributes)
      attributes.each_with_object({}) do |(key, value), normalized|
        normalized_key = CONTEXT_KEY_ALIASES.fetch(key, key)
        normalized[normalized_key] = normalize_context_value(normalized_key, value)
      end
    end

    def normalize_context_value(key, value)
      case key
      when :authn
        value || Actor::Authentication::NULL
      when :authz
        value || Actor::Authz::NULL
      when :step_up
        value || Actor::StepUp::NULL
      when :configuration
        value || Actor::Configuration::NULL
      else
        value
      end
    end
  end
end
