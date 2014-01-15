browserPrefixes = ['-webkit-', '-moz-', '-ms-', '']

window.PCEJS =
  #  default properties
  containerSel: '#pcejs'
  canvasId: 'canvas'
  doubleBuffer: true
  printEnabled: true
  touchCurrentFirst: null
  canvasWidth: 512
  canvasHeight: 342
  canvasScale: 1
  canvasOffset: 0
  zoomControls: false
  argv: ['-c','pce-config.cfg','-r']

  init: (@config = {}) ->
    _.extend(this, @config) # allow configuration override

    @preInit()
    @moduleInit()
    @postInit()

  preInit: ->
    @container = $(@containerSel)
    # include emscripten boilerplate html
    @container.html(@containerHTML())

    if (@doubleBuffer)
      # double buffer front canvas
      @frontCanvas = document.getElementById(@canvasId)
      @frontContext = @frontCanvas.getContext('2d')

      # double buffer back canvas
      @backCanvas = document.createElement('canvas')
      @backContext = @backCanvas.getContext('2d')
    else
      # single buffer canvas
      @frontCanvas = @backCanvas = document.getElementById(@canvasId)
      @frontContext = @backContext = @backCanvas.getContext('2d')

    @layoutFrontCanvas()

  moduleInit: ->
    # emscripten module object initialisation
    # injects config and behaviour into emscripen compiled module
    @module =
      'arguments': @argv
      preRun: [
        # @mountPersistentFS.bind(this)
      ]
      postRun: []
      print: if (!@printEnabled) then (->) else console.log.bind(console)
      printErr: if (!@printEnabled) then (->) else ((text) -> console.warn(text))
      canvas: @backCanvas
      canvasFront: if @doubleBuffer then @frontCanvas else null
      totalDependencies: 0
      setStatus: (text) ->
        if (@setStatus.interval) then clearInterval(@setStatus.interval)
        m = text.match(/([^(]+)\((\d+(\.\d+)?)\/(\d+)\)/)
        statusElement = $('#status').get(0)
        progressElement = $('#progress').get(0)
        if (m)
          text = m[1]
          progressElement.value = parseInt(m[2])*100
          progressElement.max = parseInt(m[4])*100
          progressElement.hidden = false
        else
          progressElement.value = null
          progressElement.max = null
          progressElement.hidden = true

        statusElement.innerHTML = text

      monitorRunDependencies: (remainingDependencies) ->
        @totalDependencies = Math.max(@totalDependencies, remainingDependencies)

        @setStatus(if remainingDependencies then 'Preparing... (' + (@totalDependencies-remainingDependencies) + '/' + @totalDependencies + ')' else 'All downloads complete.')

        $(document).trigger('dependenciesLoaded') unless remainingDependencies

  postInit: ->
    @bindTouchEventHandlers()

    @initDoubleBuffer() if @doubleBuffer

    $('#gofullscreen').click ->
      @module.requestFullScreen($('#pointerLock').get(0).checked,$('#resize').get(0).checked)

    @module.setStatus('Downloading...')

    @addZoomControls() if @zoomControls
    @addAboutLink()

    window.Module = @module

  mountPersistentFS: ->
    FS.mkdir('/data')
    FS.mount(IDBFS, {}, '/data')
    FS.syncfs(true, (err) -> console.error(err))

  syncPersistentFS: ->
    FS.syncfs((err) -> console.error(err))

  initDoubleBuffer: ->
    # proxy events from front canvas to back canvas
    _.each ['mousedown', 'mouseup', 'mousemove', 'mouseout'], (event) =>
      @module["canvasFront"].addEventListener(event, (e) =>
        try
          @module["canvas"].dispatchEvent(e)
        catch e
          # console.warn('failed to dispatch '+event, e)
      , true)

    # start double buffered render loop
    @renderToFrontCanvas()

  renderToFrontCanvas: ->
    @frontContext.drawImage(@backCanvas, 0, 0)
    window.requestAnimationFrame(@renderToFrontCanvas.bind(this))

  touchToMouseEvent: (event) ->
    # console.log(event)
    firstTouch = event.changedTouches[0]
    mouseEventType = ""
    switch event.type
      when "touchstart" then mouseEventType = "mousedown"
      when "touchmove"  then mouseEventType = "mousemove"        
      when "touchend"   then mouseEventType = "mouseup"
      else return

    if (event.type == 'touchstart') 
      @touchCurrentFirst = firstTouch

    if (event.type == 'touchmove') 
      event.preventDefault()
      return false

    if ( event.type == 'touchmove' && @touchCurrentFirst && !( Math.abs(firstTouch.screenX - @touchCurrentFirst.screenX) > 30 || Math.abs(firstTouch.screenY - @touchCurrentFirst.screenY) > 30)) 
      # console.log('drag less than 10px')
      return
    
    # console.log('proxying event of type', event.type, 'to type', mouseEventType)

    simulatedEvent = document.createEvent("MouseEvent")
    simulatedEvent.initMouseEvent(
      mouseEventType, true, true, window, 1, 
      firstTouch.screenX, firstTouch.screenY, 
      firstTouch.clientX, firstTouch.clientY, false, 
      false, false, false, 0, null
    )

    firstTouch.target.dispatchEvent(simulatedEvent)

    Browser.step_func() if Browser # emscripten runtime method

  layoutFrontCanvas:  ->
    @container.find('.emscripten_border').height((@canvasHeight)*@canvasScale)
    @frontCanvas.width = @canvasWidth
    @frontCanvas.height = @canvasHeight
    $(@frontCanvas).css(_.reduce(browserPrefixes, (css, prefix) =>
      css["#{prefix}transform"] = "scale(#{@canvasScale})"
      css["#{prefix}transform-origin"] = "center top"
      css
    , {}))
    
  bindTouchEventHandlers: ->
    _.each ['touchstart','touchend', 'touchmove'], (event) =>
      mainCanvas = @module.canvasFront || @module.canvas
      mainCanvas.addEventListener(event, (-> @touchToMouseEvent), true)

  addAboutLink: ->
    @container
      .append $('<small><a href="https://github.com/jsdf/pce/">about pce.js emulator</a></small>')

  addZoomControls: ->
    @container
      .append $('<div class="zoom-controls"></div>')
        .append($('<label>Scale:</label>'))
        .append _.map [1,1.5,2], (zoom) ->
          $('<input />',  {'type': 'button', 'value': zoom+"x", 'data-scale': zoom}).get(0)

    $(document).on 'click', '.zoom-controls input[type=button]', (event) =>
      console.log $(event.target)
      console.log $(event.target).attr('data-scale')
      @canvasScale = parseFloat($(event.target).attr('data-scale'),10)
      @layoutFrontCanvas()

  containerHTML: -> """
    <div class="emscripten" id="status">Downloading...</div>
    <div class="emscripten">
      <progress value="0" max="100" id="progress" hidden=1></progress>
    </div>
    <div class="emscripten_border">
      <canvas class="emscripten" id="#{@canvasId}" oncontextmenu="event.preventDefault()"></canvas>
    </div>
    <div class="emscripten" id="fullscreencontrols">
      <input type="checkbox" id="resize">Resize canvas
      <input type="checkbox" id="pointerLock" checked>Lock/hide mouse pointer
      &nbsp&nbsp&nbsp
      <input type="button" value="Fullscreen" id="gofullscreen">
    </div>
    <textarea class="emscripten" id="output" rows="8"></textarea>
    """
