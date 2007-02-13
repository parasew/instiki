require 'digest/sha1'
module ActionView
  module Helpers
    module TagHelper
      # Now that form_tag accepts blocks, it was easier to alias tag when name == :form
      def tag_with_form_spam_protection(name, *args)
        returning tag_without_form_spam_protection(name, *args) do |out|
          if name == :form && @protect_form_from_spam
            session[:form_keys] ||= {}
            form_key = Digest::SHA1.hexdigest(self.object_id.to_s + rand.to_s)
            session[:form_keys][form_key] = 0
            out << enkode(hidden_field_tag('_form_key', form_key))
          end
        end
      end
      
      alias_method :tag_without_form_spam_protection, :tag
      alias_method :tag, :tag_with_form_spam_protection
    end
    
    # module FormTagHelper
    #   def form_tag_with_spam_protection(*args, &proc)
    #     form_tag_method_with_spam_protection :form_tag, *args, &proc
    #   end
    #   
    #   # alias_method_chain :form_tag, :spam_protection
    #   alias_method :form_tag_without_spam_protection, :form_tag
    #   alias_method :form_tag, :form_tag_with_spam_protection
    #   
    #   protected
    #     def form_tag_method_with_spam_protection(method_name, *args, &proc)
    #       old_method_name = "#{method_name}_without_spam_protection"
    #       returning send(old_method_name, *args) do |out|
    #         if @protect_form_from_spam
    #           session[:form_keys] ||= {}
    #           form_key = Digest::SHA1.hexdigest(self.object_id.to_s + rand.to_s)
    #           session[:form_keys][form_key] = 0
    #           out << enkode(hidden_field_tag('_form_key', form_key))
    #         end
    #       end
    #     end
    #     
    # 
    # end
    #
    # module PrototypeHelper
    #   def form_remote_tag_with_spam_protection(*args, &proc)
    #     form_tag_method_with_spam_protection :form_remote_tag, *args, &proc
    #   end
    # 
    #   # alias_method_chain :form_remote_tag, :spam_protection
    #   alias_method :form_remote_tag_without_spam_protection, :form_remote_tag
    #   alias_method :form_remote_tag, :form_remote_tag_with_spam_protection
    # end
  end
end