#= require_self
#= require ./editable.selection

class Carmenta.Regions.Editable
  type = 'editable'

  constructor: (@element, @options = {}) ->
    Carmenta.log('making editable', @element, @options)

    @window = @options.window
    @document = @window.document
    @type = @element.data('type')
    @history = new HistoryBuffer()
    @build()
    @bindEvents()


  build: ->
    @element.addClass('carmenta-region')

    # mozilla: set some initial content so everything works correctly
    @html('&nbsp;') if $.browser.mozilla && @html() == ''

    # set overflow and width just in case
    width = @element.scrollWidth
    @element.css({overflow: 'auto'}) unless @element.css('overflow') == 'hidden'
    @element.css({maxWidth: width}) if width

    # mozilla: there's some weird behavior when the element isn't a div
    @specialContainer = $.browser.mozilla && @element.get(0).tagName != 'DIV'

    # make it editable and add the basic editor settings
    @element.get(0).contentEditable = true
    @execCommand('styleWithCSS', {value: false})
    @execCommand('insertBROnReturn', {value: true})
    @execCommand('enableInlineTableEditing', {value: false})
    @execCommand('enableObjectResizing', {value: false})


  bindEvents: ->
    Carmenta.bind 'focus:frame', =>
      return unless Carmenta.region == @
      @focus()
      Carmenta.trigger('region:update', {region: @})

    Carmenta.bind 'action', (event, options) =>
      return unless Carmenta.region == @
      @execCommand(options.action, options) if options.action

    @element.bind 'paste', =>
      return unless Carmenta.region == @
      Carmenta.changes = true
      html = @html()
      event.preventDefault() if @specialContainer
      setTimeout((=> @handlePaste(html)), 1)

    @element.bind 'drop', =>
      console.debug('dropped')

    @element.focus =>
      Carmenta.region = @

    @element.blur =>
      Carmenta.trigger('region:blur', {region: @})

    @element.mouseup =>
      Carmenta.trigger('region:update', {region: @})

    @element.keydown (event) =>
      Carmenta.changes = true
      switch event.keyCode

        when 13 # enter
          if $.browser.webkit
            event.preventDefault()
            @execCommand('insertlinebreak')
          else if @specialContainer
            # mozilla: pressing enter in any elemeny besides a div handles strangely
            @execCommand('insertHTML', {value: '<br/>'})
            event.preventDefault()

        when 90 # undo and redo
          break unless event.metaKey
          event.preventDefault()
          if event.shiftKey then @execCommand('redo') else @execCommand('undo')

        when 9 # tab
          event.preventDefault()
          container = @selection().commonAncestor()
          handled = false

          # indent when inside of an li
          if container.closest('li', @element).length
            handled = true
            if event.shiftKey then @execCommand('outdent') else @execCommand('indent')

          @execCommand('insertHTML', {value: '&nbsp; '}) unless handled

      if event.metaKey
        switch event.keyCode

          when 66 # b
            @execCommand('bold')
            event.preventDefault()

          when 73 # i
            @execCommand('italic')
            event.preventDefault()

          when 85 # u
            @execCommand('underline')
            event.preventDefault()


    @element.keyup =>
      Carmenta.trigger('region:update', {region: @})


  html: (value = null) ->
    if value
      @element.html(value)
    else
      @element.find('meta').remove()
      @element.html().replace(/^\s+|\s+$/g, '')


  selection: ->
    return new Carmenta.Regions.Editable.Selection(@window.getSelection(), @document)


  focus: ->
    @element.focus()


  path: ->
    container = @selection().commonAncestor()
    container.parentsUntil(@element)


  currentElement: ->
    element = @selection().commonAncestor()
    element = element.parent() if element.get(0).nodeType == 3
    return element


  handlePaste: (prePasteHTML) ->
    prePasteHTML = prePasteHTML.replace(/^\<br\>/, '')

    # remove any regions that might have been pasted
    @element.find('.carmenta-region').remove()

    # handle pasting from ms office etc
    html = @html()
    if html.indexOf('<!--StartFragment-->') > -1 || html.indexOf('="mso-') > -1 || html.indexOf('<o:') > -1 || html.indexOf('="Mso') > -1
      cleaned = prePasteHTML.singleDiff(@html()).sanitizeHTML()
      try
        @document.execCommand('undo', false, null)
        @execCommand('insertHTML', {value: cleaned})
      catch error
        @html(prePasteHTML)
        Carmenta.modal '/carmenta/modals/sanitizer', {
          title: 'HTML Sanitizer (Starring Clippy)',
          afterLoad: -> @element.find('textarea').val(cleaned.replace(/<br\/>/g, '\n'))
        }


  execCommand: (action, options = {}) ->
    @element.focus

    # use a custom handler if there's one, otherwise use execCommand
    if handler = Carmenta.config.behaviors[action] || Carmenta.Regions.Editable.actions[action]
      handler.call(@, @selection(), options)
    else
      sibling = @element.get(0).previousSibling if action == 'indent'
      options.value = $('<div>').html(options.value).html() if action == 'insertHTML' && options.value && options.value.get
      Carmenta.log('execCommand', action, options.value)
      try
        @document.execCommand(action, false, options.value)
      catch error
        # mozilla: indenting when there's no br tag handles strangely
        @element.prev().remove() if action == 'indent' && @element.prev() != sibling



# Custom handled actions (eg. things that execCommand doesn't do, or doesn't do well)
Carmenta.Regions.Editable.actions =

  removeformatting: (selection) -> selection.insertTextNode(selection.textContent())

  backcolor: (selection, options) -> selection.wrap("<span style=\"background-color:#{options.value.toHex()}\">", true)

  overline: (selection, options) -> selection.wrap('<span style="text-decoration:overline">', true)

  style: (selection, options) -> selection.wrap("<span class=\"#{options.value}\">", true)

  replaceHTML: (selection, options) -> @html(options.value)

  insertLink: (selection, options) -> selection.insertNode(options.value)

  replaceLink: (selection, options) ->
    selection.selectNode(options.node)
    html = $('<div>').html(selection.content()).find('a').html()
    selection.replace($(options.value, selection.context).html(html))