Browser = require 'browser'
Editor = require 'editor'
Extension = require 'extension'
Event = require 'event'
KeyBinder = require 'key-binder'
Native = require 'native'
Storage = require 'storage'

fs = require 'fs'
_ = require 'underscore'

# This a weirdo file. We don't create a Window class, we just add stuff to
# the DOM window.
windowAdditions =
  editor: null

  browser: null

  extensions: {}

  appRoot: OSX.NSBundle.mainBundle.resourcePath

  path: null

  startup: () ->
    KeyBinder.register "window", window

    @path = $atomController.path
    @setTitle _.last @path.split '/'
    
    $atomController.scan_select_compare(@path, null, null)

    # Remember sizing!
    defaultFrame = x: 0, y: 0, width: 600, height: 800
    frame = Storage.get "window.frame.#{@path}", defaultFrame
    rect = OSX.CGRectMake(frame.x, frame.y, frame.width, frame.height)
    $atomController.window.setFrame_display rect, true

    @editor = new Editor
    @browser = new Browser

    @loadExtensions()
    @loadKeyBindings()
    @loadSettings()

    @editor.restoreOpenBuffers()

    $atomController.window.makeKeyWindow

  shutdown: ->
    extension.shutdown() for name, extension of @extensions

    frame = $atomController.window.frame
    x = frame.origin.x
    y = frame.origin.y
    width = frame.size.width
    height = frame.size.height

    Storage.set "window.frame.#{@path}", {x:x, y:y, width:width, height:height}

  loadExtensions: ->
    extension.shutdown() for name, extension of @extensions
    @extensions = {}

    extensionPaths = fs.list require.resourcePath + "/extensions"
    for extensionPath in extensionPaths when fs.isDirectory extensionPath
      try
        extension = require extensionPath
        @extensions[extension.name] = new extension
      catch error
        console.warn "window: Loading Extension '#{fs.base extensionPath}' failed."
        console.warn error

    # After all the extensions are created, start them up.
    for name, extension of @extensions
      try
        extension.startup()
      catch error
        console.warn "window: Extension #{extension.constructor.name} failed to startup."
        console.warn error

    Event.trigger 'extensions:loaded'

  loadKeyBindings: ->
    KeyBinder.load "#{@appRoot}/static/key-bindings.coffee"
    if fs.isFile "~/.atomicity/key-bindings.coffee"
      KeyBinder.load "~/.atomicity/key-bindings.coffee"

  loadSettings: ->
    if fs.isFile "~/.atomicity/settings.coffee"
      require "~/.atomicity/settings.coffee"

  showConsole: ->
    $atomController.webView.inspector.showConsole true

  setTitle: (title) ->
    $atomController.window.title = title

  reload: ->
    @shutdown()
    $atomController.close
    OSX.NSApp.createController @path

  open: (path) ->
    $atomController.window.makeKeyAndOrderFront $atomController
    Event.trigger 'window:open', path

  close: (path) ->
    @shutdown()
    $atomController.close
    Event.trigger 'window:close', path

  handleKeyEvent: ->
    KeyBinder.handleEvent.apply KeyBinder, arguments

  triggerEvent: ->
    Event.trigger arguments...

  canOpen: (path) ->
    parent = @path.replace(/([^\/])$/, "$1/")
    child = path.replace(/([^\/])$/, "$1/")

    # If the child is contained by the parent, it can be opened by this window
    child.match "^" + parent

for key, value of windowAdditions
  console.warn "DOMWindow already has a key named `#{key}`" if window[key]
  window[key] = value
