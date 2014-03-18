{View} = require 'atom'

MinimapEditorView = require './minimap-editor-view'

CONFIGS = require './config'

minTop = 0
maxTop = 0

scaleX = 1
scaleY = 1

module.exports =
class MinimapView extends View
  @content: ->
    @div class: 'minimap', =>
      @div outlet: 'miniOverlayer', class: "minimap-overlayer"

  configs: {}

  constructor: (@paneView) ->
    super

  initialize: ->
    @attach()

    @on('mousewheel', @mouseWheel.bind(this))
    @on('mousedown', @mouseDown.bind(this))

    @subscribe @paneView.model.$activeItem, @onActiveItemChanged
    @subscribe @paneView.model, 'destroy', => @destroy()

    #@subscribe atom.workspaceView, 'cursor:moved', =>
    #  @update()

  attach: ->
    themeProp = 'minimap.theme'
    @subscribe atom.config.observe themeProp, callNow: true, =>
      @configs.theme = atom.config.get(themeProp) || CONFIGS.theme
      @updateTheme()

  destroy: ->
    @remove()
    @detach()

  # Update Styles
  updateTheme: ->
    @attr 'data-theme': this.configs.theme

  onActiveItemChanged: (item) =>
    # Fix called twice when open minimap!
    return if @activeItem == item
    @activeItem = item
    @getActiveEditor()
    @updateMinimapView()

  getActiveEditor: ->
    @editorView = @paneView.viewForItem(@activeItem)
    # Ignore `Settings Tab` or `Tabs` are empty.
    if !@editorView || !@editorView.hasClass('editor')
      return @editor = @scrollView = null
    @editor = @editorView.getEditor()
    @scrollView = @editorView.find('.scroll-view')
    @scrollViewLines = @scrollView.find('.lines')


  # wtf? Long long function!
  updateMinimapView: ->
    unless @paneView.find('.minimap').length
      @miniEditorView = new MinimapEditorView()
      @miniScrollView = @miniEditorView.find('.scroll-view')
      @miniOverlayer.before(@miniEditorView)
      @paneView.append(this)

    if !@editor
      @addClass('hide')
      return
    if @hasClass('hide')
      @removeClass('hide')

    # update minimap-editor
    setImmediate =>
      # FIXME Due to racing conditions during the `destroyed`
      # event dispatch the editor can be null, until a better
      # solution is implemented it will prevent the delayed
      # code from raising an error.
      if @editor?
        @miniScrollView[0].style.webkitTransform =
          @miniScrollView[0].style.transform = 'translate3d(0, 0, 0)'
        @miniEditorView.update(@editor.getGrammar(), @editor.getText())

    # offset minimap
    @offset({ 'top': @editorView.offset().top })

    # current editor bind scrollTop event
    @editor.off('scroll-top-changed.editor')
    @editor.on('scroll-top-changed.editor', @scrollTop.bind(this))
    @editor.off('scroll-left-changed.editor')
    @editor.on('scroll-left-changed.editor', @scrollLeft.bind(this))

    # reset minimap layer size
    @reset()

    # get rects
    @editorViewRect = @getEditorViewClientRect()
    @scrollViewRect = @getScrollViewClientRect()
    @miniScrollViewRect = @miniEditorView.getClientRect()

    # reset minimap-editor
    maxTop = @miniEditorView.height()

    # reset minimap-overlayer
    @miniOverlayer.css
      height: @editorViewRect.height
      '-webkit-transform': 'translate3d(0, 0, 0)'
      transform: 'translate3d(0, 0, 0)'

    scaleX = .2
    scaleY = scaleX * .8
    width = 125 / scaleX
    x = y = 0
    @transform(width, [scaleX, scaleY], [x, y])
    #if @scrollViewRect.height < @editorViewRect.height #else

    @scrollTop(@editorView.scrollTop())


  reset: ->
    scaleX = scaleY = 1
    @transform(125, [scaleX, scaleY], [0, 0])

  getEditorViewClientRect: ->
    @scrollView[0].getBoundingClientRect()

  getScrollViewClientRect: ->
    @scrollViewLines[0].getBoundingClientRect()

  mouseWheel: (e) ->
    {wheelDeltaX, wheelDeltaY} = e.originalEvent
    if wheelDeltaX
      @editorView.scrollLeft(@editorView.scrollLeft() - wheelDeltaX)
    if wheelDeltaY
      @editorView.scrollTop(@editorView.scrollTop() - wheelDeltaY)

  scrollLeft: (left) ->
    @miniScrollView.scrollLeft(left * scaleX)

  scrollTop: (top) ->
    h = @miniEditorView.height() * scaleY
    if h > @scrollView.height()
      miniOverLayerHeight = @miniOverlayer.height()
      n = top / (@scrollViewLines.outerHeight() - @editorView.height())
      #@miniScrollView.css({ top: -(@miniScrollView.outerHeight() - miniOverLayerHeight / scaleY) * n })
      @miniScrollView[0].style.webkitTransform =
        @miniScrollView[0].style.transform = 'translate3d(0, ' + (-(@miniScrollView.outerHeight() - miniOverLayerHeight / scaleY) * n) + 'px, 0)'
      #@miniOverlayer.css({ top: n * (miniOverLayerHeight / scaleY - miniOverLayerHeight) })
      @miniOverlayer[0].style.webkitTransform =
        @miniOverlayer[0].style.transform = 'translate3d(0, ' + (n * (miniOverLayerHeight / scaleY - miniOverLayerHeight)) + 'px, 0)'
    else
      @miniOverlayer[0].style.webkitTransform =
        @miniOverlayer[0].style.transform = 'translate3d(0, ' + top + 'px, 0)'

  mouseDown: (e) ->
    console.dir(e)

  transform: (width, scale, xy) ->
    scaleStr = 'scale(' + scale.join(',') + ')'
    translateStr = 'translate3d(' + xy.join(',') + 'px, 0)'
    @[0].style.width = width + 'px'
    @[0].style.webkitTransform =
      @[0].style.transform = scaleStr + ' ' + translateStr
