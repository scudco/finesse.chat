module ApplicationHelper
  AUTHOR_COLORS = %w[
    #e11d48
    #dc2626
    #ea580c
    #d97706
    #ca8a04
    #16a34a
    #059669
    #0891b2
    #2563eb
    #7c3aed
    #9333ea
    #db2777
  ].freeze

  def author_color(author)
    AUTHOR_COLORS[author.to_s.bytes.sum % AUTHOR_COLORS.length]
  end
end
