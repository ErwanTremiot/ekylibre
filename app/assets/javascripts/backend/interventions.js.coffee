(($) ->
  'use strict'

  $.value = (element) ->
    if element.is(":ui-selector")
      return element.selector("value")
    else
      return element.val()

  # Interventions permit to enhances data input through context computation
  # The concept is: When an update is done, we ask server which are the impact on
  # other fields and on updater itself if necessary
  $.interventions =

    # Serialize global data with data-procedure-global attribute
    serializeGlobal: (procedure) ->
      global = {}
      $("*[data-procedure='#{procedure}'][data-procedure-global]").each ->
        global[$(this).data('procedure-global')] = $.value $(this)
      global

    serialize: (procedure) ->
      casting = {}
      $("*[data-procedure='#{procedure}'][data-variable-handler]").each (index) ->
        variable = $(this).data('variable')
        casting[variable] ?= {}
        casting[variable].handlers ?= {}
        casting[variable].handlers[$(this).data('variable-handler')] = $.value $(this)

      $("*[data-procedure='#{procedure}'][data-variable-destination]").each (index) ->
        variable = $(this).data('variable')
        casting[variable] ?= {}
        casting[variable].destinations ?= {}
        casting[variable].destinations[$(this).data('variable-destination')] = $.value $(this)

      $("*[data-procedure='#{procedure}'][data-variable-actor]").each (index) ->
        variable = $(this).data('variable')
        casting[variable] ?= {}
        casting[variable].actor = $.value $(this)

      $("*[data-procedure='#{procedure}'][data-variable-variant]").each (index) ->
        variable = $(this).data('variable')
        casting[variable] ?= {}
        casting[variable].variant = $.value $(this)

      casting

    unserialize: (procedure, casting, updater) ->
      for variable, attributes of casting
        if attributes.actor?
          $("*[data-procedure='#{procedure}'][data-variable-actor='#{variable}']").each (index) ->
            element = $(this)
            if element.is(":ui-selector")
              if attributes.actor != element.selector("value")
                element.selector("value", attributes.actor)
            else if attributes.actor != parseInt element.val()
              element.val(attributes.actor)
                
        if attributes.variant?
          $("*[data-procedure='#{procedure}'][data-variable-variant='#{variable}']").each (index) ->
            element = $(this)
            if element.is(":ui-selector")
              if attributes.variant != element.selector("value")
                element.selector("value", attributes.variant)
            else if attributes.variant != parseInt element.val()
              element.val(attributes.variant)
                
        if attributes.handlers?
          for handler, value of attributes.handlers
            $("*[data-procedure='#{procedure}'][data-variable='#{variable}'][data-variable-handler='#{handler}']").each (index) ->
              if $(this).is(":ui-mapeditor")
                $(this).mapeditor "show", value
                $(this).mapeditor "edit", value
                try
                  $(this).mapeditor "view", "edit"
              else if value != parseFloat $(this).val()
                unless updater == $(this).data('intervention-updater')
                  $(this).val(value)
                
        if attributes.destinations?
          for destination, value of attributes.destinations
            $("*[data-procedure='#{procedure}'][data-variable='#{variable}'][data-variable-destination='#{destination}']").each (index) ->
              # TODO: Find a better way later to manage different datatypes like geometry
              if destination is 'shape'
                $(this).val(JSON.stringify(value))
              else
                $(this).val(value)
      

    refresh: (origin) ->
      procedure = origin.data('procedure')
      computing = $("*[data-procedure-computing='#{procedure}']")
      unless computing.length > 0
        console.log "No computing element for #{procedure}"
        console.log computing
      computing = computing.first()
      if computing.prop('state') isnt 'waiting'
        # Serialize data
        intervention =
          procedure: procedure
          updater: origin.data('intervention-updater')
          global:  $.interventions.serializeGlobal(procedure)
          casting: $.interventions.serialize(procedure)

        # Ask server for reverberated updates
        initialValue = $.value($("*[data-intervention-updater='#{intervention.updater}']").first())
        $.ajax
          url: computing.val()
          data: intervention
          beforeSend: ->
            computing.prop 'state', 'waiting'
          error: (request, status, error) ->
            computing.prop 'state', 'ready'
          success: (data, status, request) ->
            computing.prop 'state', 'ready'
            # Updates elements with new values
            $.interventions.unserialize(procedure, data, intervention.updater)
            if initialValue != $.value($("*[data-intervention-updater='#{intervention.updater}']").first())
              $.interventions.refresh origin

  ##############################################################################
  # Triggers
  $(document).on 'keyup mapchange', '*[data-variable-handler]', ->
    $(this).each ->
      $.interventions.refresh $(this)

  $(document).on 'change', '*[data-variable-actor], *[data-variable-variant], *[data-procedure-global]', ->
    $(this).each ->
      $.interventions.refresh $(this)

  true
) jQuery
