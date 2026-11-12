# frozen_string_literal: true

class JsonbKeysUniquenessValidator < ActiveModel::EachValidator
  public

  def check_validity!
    keys = options[:keys]
    unless keys.is_a?(Array) && keys.present? && keys.uniq == keys &&
        keys.all? { |key| key.is_a?(String) && key.match?(/\A[a-z_][a-z0-9_]*\z/) }
      raise ArgumentError, "JSON uniqueness keys must be distinct simple string keys"
    end

    predicate = options[:predicate]
    unless predicate.is_a?(Hash) && predicate.present? &&
        predicate.all? { |column, value| column.is_a?(Symbol) && scalar_predicate_value?(value) }
      raise ArgumentError, "JSON uniqueness predicate must map symbol columns to scalar values"
    end

    writer = options[:writer]
    return if writer.is_a?(Class) && writer < ActiveRecord::Base && writer.abstract_class?

    raise ArgumentError, "JSON uniqueness writer must be an abstract Active Record connection owner"

  end

  def validate(record)
    raise ArgumentError,
          "JSON uniqueness record must belong to its configured writer" unless record.is_a?(options.fetch(:writer))

    predicate_for(record.class)
    super
  end

  def predicate_for(model)
    predicate = options.fetch(:predicate)
    predicate.each do |column, expected|
      column_name = column.to_s
      unless model.columns_hash.key?(column_name)
        raise ArgumentError, "JSON uniqueness predicate must reference an existing database column"
      end
      unless model.type_for_attribute(column_name).cast(expected) == expected
        raise ArgumentError, "JSON uniqueness predicate values must match their database column types"
      end
    end
    predicate
  end

  def validate_each(record, attribute, value)
    predicate = predicate_for(record.class)
    return unless predicate.all? { |column, expected| record[column] == expected }
    return unless value.is_a?(Hash)

    context = value.stringify_keys
    keys = options.fetch(:keys)
    # The owning CHECK rejects malformed tuples. This validator compares text keys only.
    return unless keys.all? { |key| context[key].is_a?(String) }

    duplicate =
      options.fetch(:writer).connected_to(role: :writing) do
        relation = record.class.unscoped.where(predicate)
        keys.each do |key|
          extraction = Arel::Nodes::InfixOperation.new(
            "->>", record.class.arel_table[attribute], Arel::Nodes.build_quoted(key),
          )
          bind = ActiveRecord::Relation::QueryAttribute.new(key, context.fetch(key), ActiveRecord::Type::String.new)
          relation = relation.where(extraction.eq(Arel::Nodes::BindParam.new(bind)))
        end
        relation = relation.where.not(record.class.primary_key => record.id_in_database) if record.persisted?
        relation.exists?
      end
    return unless duplicate

    record.errors.add(:base, :taken, **options.slice(:strict))
  end

  private

  def scalar_predicate_value?(value)
    value.nil? || value.is_a?(String) || value.is_a?(Integer) || value == true || value == false
  end
end
