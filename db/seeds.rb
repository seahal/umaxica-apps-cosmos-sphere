# typed: false
# frozen_string_literal: true

# Replay retained audit reference catalogs after a schema-only load.
[
  ClientChronicleEvent, ClientChronicleLevel, OperatorChronicleEvent, OperatorChronicleLevel,
  AppPreferenceChronicleEvent, AppPreferenceChronicleLevel,
  ComPreferenceChronicleEvent, ComPreferenceChronicleLevel,
  OrgPreferenceChronicleEvent, OrgPreferenceChronicleLevel,
].each do |model|
  connection = model.lease_connection
  table = connection.quote_table_name(model.table_name)
  model::DEFAULTS.each do |id|
    connection.execute("INSERT INTO #{table} (id) VALUES (#{connection.quote(id)}) ON CONFLICT (id) DO NOTHING")
  end
end
