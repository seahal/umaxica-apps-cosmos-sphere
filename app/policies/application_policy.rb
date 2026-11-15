# typed: false
# frozen_string_literal: true

# Local RP policies receive a cell-local principal explicitly.
class ApplicationPolicy < ActionPolicy::Base
  authorize :user, optional: true

  alias_rule :edit?, to: :update?
  alias_rule :new?, to: :create?

  public

  def index? = false

  public

  def show? = false

  public

  def create? = false

  public

  def update? = false

  public

  def destroy? = false

  relation_scope do |relation|
    relation.none
  end
end
