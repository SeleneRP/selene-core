class_name ScriptManager
extends Node

signal script_printed(message: String)

var vm: LuauVM

class CallableWrapper:
	var callable: Callable

	func _init(p_callable: Callable):
		callable = p_callable

	func __lua_call(pvm: LuauVM):
		var narg = pvm.lua_gettop()
		var args = []
		for i in range(2, narg):
			args.append(pvm.lua_tovariant(i))
		var result = callable.callv(args)
		pvm.lua_pushvariant(result)
		return 1

func _ready():
	vm = LuauVM.new()
	vm.stdout.connect(_on_vm_stdout)
	vm.open_all_libraries()

	for child in get_children():
		if "lua_load_library" in child:
			child.lua_load_library(vm)

    # Expose a custom require function since Luau does not come with packages module
	vm.lua_pushcallable(_require)
	vm.lua_setglobal("require")

	# Add property getters and setters to the object metatable
	vm.luaL_getmetatable("object")
	vm.lua_pushcallable(_lua_index)
	vm.lua_rawsetfield(-2, "__index")
	vm.lua_pushcallable(_lua_newindex)
	vm.lua_rawsetfield(-2, "__newindex")
	vm.lua_pop(1)

	add_child(vm)

func _resolve_module_path(module_path: String):
	var module_file_path = module_path.replace(".", "/") + ".lua"
	return module_file_path

func _require(pvm: LuauVM):
	var module_path = pvm.luaL_checkstring(-1)
	var file_path = _resolve_module_path(module_path)
	# TODO check existing
	var script = FileAccess.get_file_as_string(file_path)
	if pvm.lua_dostring(script) == pvm.LUA_OK:
		pvm.lua_pushvalue(-1)
	else:
		var error = pvm.lua_tostring(-1)
		print_rich("[color=red]Lua Error: %s[/color]" % error)
		pvm.lua_pop(1)
		pvm.lua_pushnil()
	return 1

func _lua_index(pvm: LuauVM):
	var node = pvm.lua_toobject(1)
	var key = pvm.luaL_checkstring(2)
	var value = null
	if node.has_method("_lua_" + key):
		pvm.lua_pushcallable(node.get("_lua_" + key))
		return 1
	if node.has_method("_lua_get_" + key):
		value = node.get("_lua_get_" + key).call(pvm)
	else:
		value = node.get(key)
	if value is Color:
		value = Vector4(value.r, value.g, value.b, value.a)
		pvm.lua_pushvector(value)
		return 1
	if value is Callable:
		pvm.lua_pushobject(CallableWrapper.new(value))
		return 1
	pvm.lua_pushvariant(value)
	return 1

func _lua_newindex(pvm: LuauVM):
	var node = pvm.lua_toobject(1)
	var key = pvm.luaL_checkstring(2)
	var value = pvm.lua_tovariant(3)
	if node.get(key) is Color:
		value = pvm.luaL_checkvector(3)
		value = Color(value.x, value.y, value.z, value.w)
	else:
		value = pvm.lua_tovariant(3)
	if "_lua_set" in node:
		node.lua_set(key, value)
	else:
		node.set(key, value)
	return 0

func _on_vm_stdout(message: String):
	script_printed.emit(message)