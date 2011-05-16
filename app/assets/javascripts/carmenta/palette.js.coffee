class Carmenta.Palette extends Carmenta.Dialog

  constructor: (@url, @name, @options = {}) ->
    super


  build: ->
    @element = $('<div>', {class: "carmenta-palette carmenta-#{@name}-palette loading", style: 'display:none'})
    @element.appendTo(@options.appendTo)


  bindEvents: ->
    Carmenta.bind 'hide:dialogs', (event, dialog) => @hide() unless dialog == @
    super


  position: (keepVisible) ->
    @element.css({top: 0, left: 0, display: 'block', visibility: 'hidden'})
    position = @button.offset()
    width = @element.width()

    position.left = position.left - width + @button.width() if position.left + width > $(window).width()

    @element.css {
      top: position.top + @button.height(),
      left: position.left,
      display: if keepVisible then 'block' else 'none',
      visibility: 'visible'
    }