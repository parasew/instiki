mime_types = YAML.load_file(Rails.root.join("config", "mime_types.yml"))
Rack::Mime::MIME_TYPES.merge!(mime_types)

# Rails 6 registers application/xhtml+xml as a synonym of :html. Instiki
# treats them as distinct content types (the controller chooses XHTML for
# certain user agents to enable MathML rendering). Re-register XHTML as its
# own Mime::Type and remove the synonym from :html so Mime[:xhtml] returns a
# distinct type.
html_type = Mime::Type.lookup_by_extension(:html)
if html_type && html_type.instance_variable_get(:@synonyms)&.include?("application/xhtml+xml")
  html_type.instance_variable_set(
    :@synonyms,
    html_type.instance_variable_get(:@synonyms) - ["application/xhtml+xml"]
  )
  # Drop the existing string-keyed lookup for the synonym so we can re-register.
  Mime::EXTENSION_LOOKUP.delete("xhtml")
  Mime::LOOKUP.delete("application/xhtml+xml")
end
Mime::Type.register("application/xhtml+xml", :xhtml) unless Mime::EXTENSION_LOOKUP.key?("xhtml")
