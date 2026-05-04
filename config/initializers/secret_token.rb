require "securerandom"

# The secret session/cookie key is automatically generated and stored in
# config/../secret on first boot, then re-read on every subsequent boot. To
# rotate the secret, delete the file — all existing sessions will be
# invalidated.

secret_file = Rails.root.join("secret")
secret = if File.exist?(secret_file)
  secret_file.read
else
  SecureRandom.hex(64).tap do |s|
    File.open(secret_file, "w", 0600) { |f| f.write(s) }
  end
end

Rails.application.config.secret_key_base = secret
