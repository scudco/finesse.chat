module ApplicationHelper
  class ChatMarkdownRenderer < Redcarpet::Render::HTML
    # Degrade headers to plain text — no h1-h6 in chat
    def header(text, level)  = text
    # Show alt text only — no images
    def image(link, title, alt) = CGI.escapeHTML(alt.to_s)
    # Drop tables, block quotes, horizontal rules
    def table(header, body)  = nil
    def hrule                = "<p>---</p>\n"
    def block_code(code, lang)
      "<pre><code>#{CGI.escapeHTML(code)}</code></pre>\n"
    end
  end

  MARKDOWN = Redcarpet::Markdown.new(
    ChatMarkdownRenderer.new(
      hard_wrap:       true,   # single newline → <br>
      escape_html:     true,   # never trust user input
      safe_links_only: true,   # block javascript: / data: hrefs
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    ),
    no_intra_emphasis:            true,  # don't italicise foo_bar_baz
    strikethrough:                true,  # ~~deleted~~
    autolink:                     true,  # bare URLs become links
    fenced_code_blocks:           true,  # ```lang ... ``` blocks
    disable_indented_code_blocks: true   # 4-space indent stays as text
  ).freeze

  ALLOWED_TAGS  = %w[strong em del br p ul ol li a code pre blockquote].freeze
  ALLOWED_ATTRS = %w[href target rel].freeze

  def render_chat_markdown(text)
    raw_html = MARKDOWN.render(text.to_s)
    sanitized = sanitize(raw_html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRS)
    sanitized.html_safe
  end

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
