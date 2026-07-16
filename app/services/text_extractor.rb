# Pulls plain text out of an uploaded Document's attached file. A PDF
# isn't text internally -- it's a page-layout format -- so pdf-reader
# parses that structure and returns just the visible text per page.
class TextExtractor
  class UnsupportedContentType < StandardError; end

  def self.call(document)
    document.file.blob.open do |file|
      case document.file.content_type
      when "application/pdf"
        extract_pdf(file)
      when "text/plain"
        file.read
      else
        raise UnsupportedContentType, document.file.content_type
      end
    end
  end

  def self.extract_pdf(file)
    PDF::Reader.new(file.path).pages.map(&:text).join("\n\n")
  end
  private_class_method :extract_pdf
end
