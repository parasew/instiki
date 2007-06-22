require 'html5lib/html5parser/phase'

module HTML5lib
  class InBodyPhase < Phase

    # http://www.whatwg.org/specs/web-apps/current-work/#in-body

    handle_start 'html'
    handle_start %w( base link meta script style ) => 'ProcessInHead'
    handle_start 'title'

    handle_start 'body', 'form', 'plaintext', 'a', 'button', 'xmp', 'table', 'hr', 'image'

    handle_start 'input', 'textarea', 'select', 'isindex', %w( marquee object )

    handle_start %w( li dd dt ) => 'ListItem'
      
    handle_start %w( address blockquote center dir div dl fieldset listing menu ol p pre ul ) => 'CloseP'

    handle_start %w( b big em font i s small strike strong tt u ) => 'Formatting'
    handle_start 'nobr'

    handle_start %w( area basefont bgsound br embed img param spacer wbr ) => 'VoidFormatting'

    handle_start %w( iframe noembed noframes noscript ) => 'Cdata', HEADING_ELEMENTS => 'Heading'

    handle_start %w( caption col colgroup frame frameset head option optgroup tbody td tfoot th thead tr ) => 'Misplaced'

    handle_start %w( event-source section nav article aside header footer datagrid command ) => 'New'

    handle_end 'p', 'body', 'html', 'form', %w( button marquee object ), %w( dd dt li ) => 'ListItem'

    handle_end %w( address blockquote center div dl fieldset listing menu ol pre ul ) => 'Block'

    handle_end HEADING_ELEMENTS => 'Heading'

    handle_end %w( a b big em font i nobr s small strike strong tt u ) => 'Formatting'

    handle_end %w( head frameset select optgroup option table caption colgroup col thead tfoot tbody tr td th ) => 'Misplaced' 

    handle_end 'br'

    handle_end %w( area basefont bgsound embed hr image img input isindex param spacer wbr frame ) => 'None'

    handle_end %w( noframes noscript noembed textarea xmp iframe ) => 'CdataTextAreaXmp'

    handle_end %w( event-source section nav article aside header footer datagrid command ) => 'New'

    def initialize(parser, tree)
      super(parser, tree)

      # for special handling of whitespace in <pre>
      @processSpaceCharactersDropNewline = false
    end

    def processSpaceCharactersDropNewline(data)
      #Sometimes (start of <pre> blocks) we want to drop leading newlines
      @processSpaceCharactersDropNewline = false
      if (data.length > 0 and data[0] == ?\n and 
        %w[pre textarea].include?(@tree.openElements[-1].name) and
        not @tree.openElements[-1].hasContent)
        data = data[1..-1]
      end
      @tree.insertText(data) if data.length > 0
    end

    def processSpaceCharacters(data)
      if @processSpaceCharactersDropNewline
        processSpaceCharactersDropNewline(data)
      else
        super(data)
      end
    end

    def processCharacters(data)
      # XXX The specification says to do this for every character at the
      # moment, but apparently that doesn't match the real world so we don't
      # do it for space characters.
      @tree.reconstructActiveFormattingElements
      @tree.insertText(data)
    end

    def startTagProcessInHead(name, attributes)
      @parser.phases[:inHead].processStartTag(name, attributes)
    end

    def startTagTitle(name, attributes)
      @parser.parseError(_("Unexpected start tag (#{name}) that belongs in the head. Moved."))
      @parser.phases[:inHead].processStartTag(name, attributes)
    end

    def startTagBody(name, attributes)
      @parser.parseError(_('Unexpected start tag (body).'))

      if (@tree.openElements.length == 1 or
        @tree.openElements[1].name != 'body')
        assert @parser.innerHTML
      else
        attributes.each do |attr, value|
          unless @tree.openElements[1].attributes.has_key?(attr)
            @tree.openElements[1].attributes[attr] = value
          end
        end
      end
    end

    def startTagCloseP(name, attributes)
      endTagP('p') if in_scope?('p')
      @tree.insertElement(name, attributes)
      @processSpaceCharactersDropNewline = true if name == 'pre'
    end

    def startTagForm(name, attributes)
      if @tree.formPointer
        @parser.parseError('Unexpected start tag (form). Ignored.')
      else
        endTagP('p') if in_scope?('p')
        @tree.insertElement(name, attributes)
        @tree.formPointer = @tree.openElements[-1]
      end
    end

    def startTagListItem(name, attributes)
      endTagP('p') if in_scope?('p')
      stopNames = {'li' => ['li'], 'dd' => ['dd', 'dt'], 'dt' => ['dd', 'dt']}
      stopName = stopNames[name]

      @tree.openElements.reverse.each_with_index do |node, i|
        if stopName.include?(node.name)
          poppedNodes = (0..i).collect { @tree.openElements.pop }
          if i >= 1
            @parser.parseError("Missing end tag%s (%s)" % [
              (i>1 ? 's' : ''),
              poppedNodes.reverse.map {|item| item.name}.join(', ')])
          end
          break
        end

        # Phrasing elements are all non special, non scoping, non
        # formatting elements
        break if ((SPECIAL_ELEMENTS + SCOPING_ELEMENTS).include?(node.name) and
          not ['address', 'div'].include?(node.name))
      end

      # Always insert an <li> element.
      @tree.insertElement(name, attributes)
    end

    def startTagPlaintext(name, attributes)
      endTagP('p') if in_scope?('p')
      @tree.insertElement(name, attributes)
      @parser.tokenizer.contentModelFlag = :PLAINTEXT
    end

    def startTagHeading(name, attributes)
      endTagP('p') if in_scope?('p')

      # Uncomment the following for IE7 behavior:
      # HEADING_ELEMENTS.each do |element|
      #   if in_scope?(element)
      #     @parser.parseError(_("Unexpected start tag (#{name})."))
      # 
      #     remove_open_elements_until do |element|
      #       HEADING_ELEMENTS.include?(element.name)
      #     end
      #
      #     break
      #   end
      # end
      @tree.insertElement(name, attributes)
    end

    def startTagA(name, attributes)
      if afeAElement = @tree.elementInActiveFormattingElements('a')
        @parser.parseError(_('Unexpected start tag (a) implies end tag (a).'))
        endTagFormatting('a')
        @tree.openElements.delete(afeAElement) if @tree.openElements.include?(afeAElement)
        @tree.activeFormattingElements.delete(afeAElement) if @tree.activeFormattingElements.include?(afeAElement)
      end
      @tree.reconstructActiveFormattingElements
      addFormattingElement(name, attributes)
    end

    def startTagFormatting(name, attributes)
      @tree.reconstructActiveFormattingElements
      addFormattingElement(name, attributes)
    end

    def startTagNobr(name, attributes)
      @tree.reconstructActiveFormattingElements
      processEndTag('nobr') if in_scope?('nobr')
      addFormattingElement(name, attributes)
    end

    def startTagButton(name, attributes)
      if in_scope?('button')
        @parser.parseError(_('Unexpected start tag (button) implied end tag (button).'))
        processEndTag('button')
        @parser.phase.processStartTag(name, attributes)
      else
        @tree.reconstructActiveFormattingElements
        @tree.insertElement(name, attributes)
        @tree.activeFormattingElements.push(Marker)
      end
    end

    def startTagMarqueeObject(name, attributes)
      @tree.reconstructActiveFormattingElements
      @tree.insertElement(name, attributes)
      @tree.activeFormattingElements.push(Marker)
    end

    def startTagXmp(name, attributes)
      @tree.reconstructActiveFormattingElements
      @tree.insertElement(name, attributes)
      @parser.tokenizer.contentModelFlag = :CDATA
    end

    def startTagTable(name, attributes)
      processEndTag('p') if in_scope?('p')
      @tree.insertElement(name, attributes)
      @parser.phase = @parser.phases[:inTable]
    end

    def startTagVoidFormatting(name, attributes)
      @tree.reconstructActiveFormattingElements
      @tree.insertElement(name, attributes)
      @tree.openElements.pop
    end

    def startTagHr(name, attributes)
      endTagP('p') if in_scope?('p')
      @tree.insertElement(name, attributes)
      @tree.openElements.pop
    end

    def startTagImage(name, attributes)
      # No really...
      @parser.parseError(_('Unexpected start tag (image). Treated as img.'))
      processStartTag('img', attributes)
    end

    def startTagInput(name, attributes)
      @tree.reconstructActiveFormattingElements
      @tree.insertElement(name, attributes)
      if @tree.formPointer
        # XXX Not exactly sure what to do here
        # @tree.openElements[-1].form = @tree.formPointer
      end
      @tree.openElements.pop
    end

    def startTagIsindex(name, attributes)
      @parser.parseError("Unexpected start tag isindex. Don't use it!")
      return if @tree.formPointer
      processStartTag('form', {})
      processStartTag('hr', {})
      processStartTag('p', {})
      processStartTag('label', {})
      # XXX Localization ...
      processCharacters('This is a searchable index. Insert your search keywords here:')
      attributes['name'] = 'isindex'
      attrs = attributes.to_a
      processStartTag('input', attributes)
      processEndTag('label')
      processEndTag('p')
      processStartTag('hr', {})
      processEndTag('form')
    end

    def startTagTextarea(name, attributes)
      # XXX Form element pointer checking here as well...
      @tree.insertElement(name, attributes)
      @parser.tokenizer.contentModelFlag = :RCDATA
      @processSpaceCharactersDropNewline = true
    end

    # iframe, noembed noframes, noscript(if scripting enabled)
    def startTagCdata(name, attributes)
      @tree.insertElement(name, attributes)
      @parser.tokenizer.contentModelFlag = :CDATA
    end

    def startTagSelect(name, attributes)
      @tree.reconstructActiveFormattingElements
      @tree.insertElement(name, attributes)
      @parser.phase = @parser.phases[:inSelect]
    end

    def startTagMisplaced(name, attributes)
      # Elements that should be children of other elements that have a
      # different insertion mode; here they are ignored
      # "caption", "col", "colgroup", "frame", "frameset", "head",
      # "option", "optgroup", "tbody", "td", "tfoot", "th", "thead",
      # "tr", "noscript"
      @parser.parseError(_("Unexpected start tag (#{name}). Ignored."))
    end

    def startTagNew(name, attributes)
      # New HTML5 elements, "event-source", "section", "nav",
      # "article", "aside", "header", "footer", "datagrid", "command"
      sys.stderr.write("Warning: Undefined behaviour for start tag #{name}")
      startTagOther(name, attributes)
      #raise NotImplementedError
    end

    def startTagOther(name, attributes)
      @tree.reconstructActiveFormattingElements
      @tree.insertElement(name, attributes)
    end

    def endTagP(name)
      @tree.generateImpliedEndTags('p') if in_scope?('p')
      @parser.parseError('Unexpected end tag (p).') unless @tree.openElements[-1].name == 'p'
      @tree.openElements.pop while in_scope?('p')
    end

    def endTagBody(name)
      # XXX Need to take open <p> tags into account here. We shouldn't imply
      # </p> but we should not throw a parse error either. Specification is
      # likely to be updated.
      unless @tree.openElements[1].name == 'body'
        # innerHTML case
        @parser.parseError
        return
      end
      unless @tree.openElements[-1].name == 'body'
        @parser.parseError(_("Unexpected end tag (body). Missing end tag (#{@tree.openElements[-1].name})."))
      end
      @parser.phase = @parser.phases[:afterBody]
    end

    def endTagHtml(name)
      endTagBody(name)
      @parser.phase.processEndTag(name) unless @parser.innerHTML
    end

    def endTagBlock(name)
      #Put us back in the right whitespace handling mode
      @processSpaceCharactersDropNewline = false if name == 'pre'

      @tree.generateImpliedEndTags if in_scope?(name)

      unless @tree.openElements[-1].name == name
        @parser.parseError(("End tag (#{name}) seen too early. Expected other end tag."))
      end

      if in_scope?(name)
        remove_open_elements_until(name)
      end
    end

    def endTagForm(name)
      endTagBlock(name)
      @tree.formPointer = nil
    end

    def endTagListItem(name)
      # AT Could merge this with the Block case
      if in_scope?(name)
        @tree.generateImpliedEndTags(name)

        unless @tree.openElements[-1].name == name
          @parser.parseError(("End tag (#{name}) seen too early. Expected other end tag."))
        end
      end

      remove_open_elements_until(name) if in_scope?(name)
    end  

    def endTagHeading(name)
      HEADING_ELEMENTS.each do |element|
        if in_scope?(element)
          @tree.generateImpliedEndTags
          break
        end
      end

      unless @tree.openElements[-1].name == name
        @parser.parseError(("Unexpected end tag (#{name}). Expected other end tag."))
      end

      HEADING_ELEMENTS.each do |element|
        if in_scope?(element)
          remove_open_elements_until { |element| HEADING_ELEMENTS.include?(element.name) }
          break
        end
      end
    end

    # The much-feared adoption agency algorithm
    def endTagFormatting(name)
      # http://www.whatwg.org/specs/web-apps/current-work/#adoptionAgency
      # XXX Better parseError messages appreciated.
      while true
        # Step 1 paragraph 1
        afeElement = @tree.elementInActiveFormattingElements(name)
        if not afeElement or (@tree.openElements.include?(afeElement) and not in_scope?(afeElement.name))
          @parser.parseError(_("End tag (#{name}) violates step 1, paragraph 1 of the adoption agency algorithm."))
          return
        # Step 1 paragraph 2
        elsif not @tree.openElements.include?(afeElement)
          @parser.parseError(_("End tag (#{name}) violates step 1, paragraph 2 of the adoption agency algorithm."))
          @tree.activeFormattingElements.delete(afeElement)
          return
        end

        # Step 1 paragraph 3
        if afeElement != @tree.openElements[-1]
          @parser.parseError(_("End tag (#{name}) violates step 1, paragraph 3 of the adoption agency algorithm."))
        end

        # Step 2
        # Start of the adoption agency algorithm proper
        afeIndex = @tree.openElements.index(afeElement)
        furthestBlock = nil
        @tree.openElements[afeIndex..-1].each do |element|
          if (SPECIAL_ELEMENTS + SCOPING_ELEMENTS).include?(element.name)
            furthestBlock = element
            break
          end
        end

        # Step 3
        if furthestBlock.nil?
          element = remove_open_elements_until { |element| element == afeElement }
          @tree.activeFormattingElements.delete(element)
          return
        end
        commonAncestor = @tree.openElements[afeIndex - 1]

        # Step 5
        furthestBlock.parent.removeChild(furthestBlock) if furthestBlock.parent

        # Step 6
        # The bookmark is supposed to help us identify where to reinsert
        # nodes in step 12. We have to ensure that we reinsert nodes after
        # the node before the active formatting element. Note the bookmark
        # can move in step 7.4
        bookmark = @tree.activeFormattingElements.index(afeElement)

        # Step 7
        lastNode = node = furthestBlock
        while true
          # AT replace this with a function and recursion?
          # Node is element before node in open elements
          node = @tree.openElements[@tree.openElements.index(node) - 1]
          until @tree.activeFormattingElements.include?(node)
            tmpNode = node
            node = @tree.openElements[@tree.openElements.index(node) - 1]
            @tree.openElements.delete(tmpNode)
          end
          # Step 7.3
          break if node == afeElement
          # Step 7.4
          if lastNode == furthestBlock
            # XXX should this be index(node) or index(node)+1
            # Anne: I think +1 is ok. Given x = [2,3,4,5]
            # x.index(3) gives 1 and then x[1 +1] gives 4...
            bookmark = @tree.activeFormattingElements.index(node) + 1
          end
          # Step 7.5
          cite = node.parent
          if node.hasContent
            clone = node.cloneNode
            # Replace node with clone
            @tree.activeFormattingElements[@tree.activeFormattingElements.index(node)] = clone
            @tree.openElements[@tree.openElements.index(node)] = clone
            node = clone
          end
          # Step 7.6
          # Remove lastNode from its parents, if any
          lastNode.parent.removeChild(lastNode) if lastNode.parent
          node.appendChild(lastNode)
          # Step 7.7
          lastNode = node
          # End of inner loop
        end

        # Step 8
        lastNode.parent.removeChild(lastNode) if lastNode.parent
        commonAncestor.appendChild(lastNode)

        # Step 9
        clone = afeElement.cloneNode

        # Step 10
        furthestBlock.reparentChildren(clone)

        # Step 11
        furthestBlock.appendChild(clone)

        # Step 12
        @tree.activeFormattingElements.delete(afeElement)
        @tree.activeFormattingElements.insert([bookmark,@tree.activeFormattingElements.length].min, clone)

        # Step 13
        @tree.openElements.delete(afeElement)
        @tree.openElements.insert(@tree.openElements.index(furthestBlock) + 1, clone)
      end
    end

    def endTagButtonMarqueeObject(name)
      @tree.generateImpliedEndTags if in_scope?(name)

      unless @tree.openElements[-1].name == name
        @parser.parseError(_("Unexpected end tag (#{name}). Expected other end tag first."))
      end

      if in_scope?(name)
        remove_open_elements_until(name)
      
        @tree.clearActiveFormattingElements
      end
    end

    def endTagMisplaced(name)
      # This handles elements with end tags in other insertion modes.
      @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
    end

    def endTagBr(name)
      @parser.parseError(_("Unexpected end tag (br). Treated as br element."))
      @tree.reconstructActiveFormattingElements
      @tree.insertElement(name, {})
      @tree.openElements.pop()
    end

    def endTagNone(name)
      # This handles elements with no end tag.
      @parser.parseError(_("This tag (#{name}) has no end tag"))
    end

    def endTagCdataTextAreaXmp(name)
      if @tree.openElements[-1].name == name
        @tree.openElements.pop
      else
        @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
      end
    end

    def endTagNew(name)
      # New HTML5 elements, "event-source", "section", "nav",
      # "article", "aside", "header", "footer", "datagrid", "command"
      STDERR.puts "Warning: Undefined behaviour for end tag #{name}"
      endTagOther(name)
      #raise NotImplementedError
    end

    def endTagOther(name)
      # XXX This logic should be moved into the treebuilder
      @tree.openElements.reverse.each do |node|
        if node.name == name
          @tree.generateImpliedEndTags

          unless @tree.openElements[-1].name == name
            @parser.parseError(_("Unexpected end tag (#{name})."))
          end

          remove_open_elements_until { |element| element == node }

          break
        else
          if (SPECIAL_ELEMENTS + SCOPING_ELEMENTS).include?(node.name)
            @parser.parseError(_("Unexpected end tag (#{name}). Ignored."))
            break
          end
        end
      end
    end

    protected

    def addFormattingElement(name, attributes)
      @tree.insertElement(name, attributes)
      @tree.activeFormattingElements.push(@tree.openElements[-1])
    end

  end
end
