# typed: false
# frozen_string_literal: true

# Local RP policies receive a cell-local principal explicitly.
class ApplicationPolicy < ActionPolicy::Base
  authorize :user, optional: true

  alias_rule :edit?, to: :update?
  alias_rule :new?, to: :create?

  def index? = false

  def show? = false

  def create? = false

  def update? = false

  def destroy? = false

  relation_scope do |relation|
    relation.none
  end
end
