# typed: false
# frozen_string_literal: true

module ApplicationHelper
  BRAND_TLD_LABELS = %w(app org net dev).freeze

  public

  def brand_tld
    label = request.host.to_s.downcase.split(".").reverse.find { |part| BRAND_TLD_LABELS.include?(part) }
    unless label
      raise ArgumentError, "Cannot derive a supported brand TLD from request host"
    end

    label.upcase
  end

  def page_title(title = nil)
    if title.present?
      content_for(:page_title, title)
      title
    else
      content_for(:page_title)
    end
  end
end
