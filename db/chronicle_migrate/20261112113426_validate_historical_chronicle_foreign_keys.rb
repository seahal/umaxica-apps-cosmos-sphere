# frozen_string_literal: true

class ValidateHistoricalChronicleForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    # Historical migrations enforce new writes but never validate the imported rows.
    # Keep the full retained audit schema reconstructible with validated references.
    validate_foreign_key(:app_document_audits, name: "fk_rails_04199ae3cc")
    validate_foreign_key(:app_document_audits, name: "fk_rails_a9e9b70220")
    validate_foreign_key(:app_preference_chronicles, name: "fk_rails_d693b46c45")
    validate_foreign_key(:app_preference_chronicles, name: "fk_rails_da47dd8941")
    validate_foreign_key(:app_timeline_audits, name: "fk_rails_2babaf0d7d")
    validate_foreign_key(:app_timeline_audits, name: "fk_rails_b95cff528f")
    validate_foreign_key(:chronicle_outbox_entries, name: "fk_rails_6a19517853")
    validate_foreign_key(:client_chronicles, name: "fk_rails_829f1830de")
    validate_foreign_key(:client_chronicles, name: "fk_rails_868bedb021")
    validate_foreign_key(:com_preference_chronicles, name: "fk_rails_592279f49b")
    validate_foreign_key(:com_preference_chronicles, name: "fk_rails_c194bd8de2")
    validate_foreign_key(:operator_chronicles, name: "fk_rails_46a8075569")
    validate_foreign_key(:operator_chronicles, name: "fk_rails_f0451c267b")
    validate_foreign_key(:org_document_audits, name: "fk_rails_46d3b866ce")
    validate_foreign_key(:org_document_audits, name: "fk_rails_ed52fec6a9")
    validate_foreign_key(:org_preference_chronicles, name: "fk_rails_3829eb3d72")
    validate_foreign_key(:org_preference_chronicles, name: "fk_rails_f932dbadd7")
    validate_foreign_key(:org_timeline_audits, name: "fk_rails_1c8eb96fbb")
    validate_foreign_key(:org_timeline_audits, name: "fk_rails_eae8a241e3")
  end

  def down
    # PostgreSQL cannot mark a validated FK NOT VALID without dropping its protection.
    raise ActiveRecord::IrreversibleMigration, "Historical Chronicle foreign key validation is retained"
  end
end
