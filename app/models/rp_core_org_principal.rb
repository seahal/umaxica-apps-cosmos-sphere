# typed: false
# frozen_string_literal: true

class RpCoreOrgPrincipal < RpCoreOrgRecord
  self.table_name = "rp_principals"

  CELL = RpCellBinding.fetch("rp_core_org")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  include PublicId

  before_validation :generate_public_id, on: :create
  before_validation :refresh_generated_public_id_after_collision, on: :create
  before_create :generate_public_id
  around_create :retry_public_id_collision
  validate :public_id_immutable_after_create, on: :update
  validates :public_id, presence: true, length: { is: PublicId::GENERATION_SIZE }, uniqueness: true

  include RpPrincipal

  has_many :identity_bindings, class_name: "RpCoreOrgIdentityBinding", foreign_key: :principal_id,
                               inverse_of: :principal,
                               dependent: :restrict_with_error
end
