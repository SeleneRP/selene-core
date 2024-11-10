extends Node

signal log(message: String, level: LogLevel, group: String)

func get_root():
	return get_tree().get_root().get_node("SeleneRoot")