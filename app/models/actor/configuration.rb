# typed: false
# frozen_string_literal: true

class Actor
  SignConfiguration =
    Data.define(
      :value,
      :enabled,
      :mode,
    )

  class Configuration
    class NullValue
      public

      def nil? = true

      public

      def ==(other)
        other.nil? || other.is_a?(self.class)
      end

      alias eql? ==

      public

      def blank? = true

      public

      def present? = false

      public

      def configured? = false

      public

      def enabled? = false

      public

      def disabled? = true

      public

      def to_s = ""

      public

      def to_a = []

      public

      def to_h = {}

      public

      def method_missing(*)
        self
      end

      public

      def respond_to_missing?(*)
        true
      end
    end

    NULL_VALUE = NullValue.new.freeze

    def initialize(values = {})
      @values = values.symbolize_keys.freeze
      freeze
    end

    public

    def with(**values)
      self.class.new(@values.merge(values))
    end

    public

    def null?
      @values.empty?
    end

    public

    def fetch(key, default = NULL_VALUE)
      @values.fetch(key.to_sym, default)
    end

    public

    def [](key)
      fetch(key)
    end

    public

    def to_h
      @values
    end

    public

    def method_missing(name, *, **)
      fetch(name)
    end

    public

    def respond_to_missing?(*)
      true
    end

    public

    def ==(other)
      other.is_a?(self.class) && @values == other.instance_variable_get(:@values)
    end

    alias eql? ==

    public

    def hash
      [self.class, @values].hash
    end

    NULL = new.freeze
  end
end
