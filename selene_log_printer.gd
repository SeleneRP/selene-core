class_name SeleneLogPrinter
extends Node

func _ready():
    SeleneInstance.log.connect(_on_log)

func _on_log(message: String, level: LogLevel.Keys, tags: Array[String]):
    var color: String
    match level:
        LogLevel.Keys.TRACE:
            color = "darkgray"
        LogLevel.Keys.DEBUG:
            color = "gray"
        LogLevel.Keys.INFO:
            color = "white"
        LogLevel.Keys.WARNING:
            color = "yellow"
        LogLevel.Keys.ERROR:
            color = "red"
    if "success" in tags:
        color = "green"
        tags.erase("success")
    if "pending" in tags:
        color = "yellow"
        tags.erase("pending")
    if "fatal" in tags:
        color = "darkred"
        tags.erase("fatal")
    if not tags.is_empty():
        print_rich("[color=%s][%s] %s[/color]" % [color, tags, message])
    else:
        print_rich("[color=%s]%s[/color]" % [color, message])