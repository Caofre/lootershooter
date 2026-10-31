LS_Events = {}

LS_Events.Listeners = {}

function LS_Events.Register(eventName, id, callback)

    LS_Events.Listeners[eventName] =
        LS_Events.Listeners[eventName] or {}

    LS_Events.Listeners[eventName][id] =
        callback

end

function LS_Events.Unregister(eventName, id)

    if not LS_Events.Listeners[eventName] then
        return
    end

    LS_Events.Listeners[eventName][id] = nil

end

function LS_Events.Call(eventName, data)

    local listeners =
        LS_Events.Listeners[eventName]

    if not listeners then
        return
    end

    for id, callback in pairs(listeners) do

        callback(data)

    end

end

LS_Events.Register(

    "Test",

    "Debug",

    function(data)

        print("Event received!")

        PrintTable(data)

    end

)