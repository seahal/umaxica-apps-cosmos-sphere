# frozen_string_literal: true

# Immutable authenticated RP access state shared by step-up evidence readers and writers.
RpAccessStateValue = Data.define(:status, :resource, :rp_session, :payload, :security_context)
