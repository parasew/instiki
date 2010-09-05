require 'digest/sha1'
module ActionView
  module Helpers
    module TagHelper
      # Now that form_tag accepts blocks, it was easier to alias tag when name == :form
      def tag_with_form_spam_protection(name, *args)
        tag_without_form_spam_protection(name, *args).tap do |out|
          if name == :form && @protect_form_from_spam
            session[:form_keys] ||= {}
            form_key = Digest::SHA1.hexdigest(self.object_id.to_s + rand.to_s)
            session[:form_keys][Digest::SHA1.hexdigest(form_key)] = [Time.now, 0]
            if session[:form_keys].length > 30
              first = session[:form_keys].values.sort { |a,b| a[0] <=> b[0] } [0]
              session[:form_keys].delete(session[:form_keys].key(first))
            end
            out << domEnkode(form_key)
          end
        end
      end
      
      alias_method :tag_without_form_spam_protection, :tag
      alias_method :tag, :tag_with_form_spam_protection
    end
  end
end

module ActionView
  module Helpers
    module TextHelper

      def domEnkode(form_key, max_length=1024 )

        rnd = 10 + (rand*90).to_i

        kodes = [
          {
            'rb' => lambda do |s|
              s.reverse
            end,
            'js' => ";kode=kode.split('').reverse().join('')"
          },
          {
            'rb' => lambda do |s|
              result = ''
              s.each_byte { |b|
                b += 3
                b-=128 if b>127
                result += b.chr
              }
              result
            end,
            'js' => (
               ";x='';for(i=0;i<kode.length;i++){c=kode.charCodeAt(i)-3;" +
               "if(c<0)c+=128;x+=String.fromCharCode(c)}kode=x"
             )
          },
          {
            'rb' => lambda do |s|
              for i in (0..s.length/2-1)
                s[i*2],s[i*2+1] = s[i*2+1],s[i*2]
              end
              s
            end,
            'js' => (
               ";x='';for(i=0;i<(kode.length-1);i+=2){" +
               "x+=kode.charAt(i+1)+kode.charAt(i)}" +
               "kode=x+(i<kode.length?kode.charAt(kode.length-1):'');"
             )
          }
        ]

        kode = "var pos=document.documentElement;while(pos && pos.lastChild && pos.lastChild.nodeType==1)pos=pos.lastChild;var hiddenfield=document.createElement('input');hiddenfield.setAttribute('type','hidden');hiddenfield.setAttribute('name','_form_key');hiddenfield.setAttribute('value','"+form_key+"');pos.parentNode.appendChild(hiddenfield);null;"

        max_length = kode.length+1 unless max_length>kode.length

        result = ''

        while kode.length < max_length
          idx = (rand*kodes.length).to_i
          kode = kodes[idx]['rb'].call(kode)
          kode = "kode=" + js_dbl_quote(kode) + kodes[idx]['js']
          js = "var kode=\n"+js_wrap_quote(js_dbl_quote(kode),79)
          js = js+"\n;var i,c,x;while(eval(kode));"
          js = "function hivelogic_enkoder(){"+js+"}hivelogic_enkoder();"
          js = '<script type="text/javascript">'+"\n<!--//--><![CDATA[//><!--\n"+js
          js = js+"\n//--><!]]>\n</script>\n"
          result = js unless result.length>max_length
        end

        result.html_safe

      end
    end
  end
end
