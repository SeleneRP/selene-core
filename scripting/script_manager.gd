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
		for i in range(2, narg + 1):
			args.append(pvm.lua_tovariant(i))
		var result = callable.callv(args)
		pvm.lua_pushvariant(result)
		return 1

func _ready():
	vm = LuauVM.new()
	vm.stdout.connect(_on_vm_stdout)
	vm.open_all_libraries()

	for child in get_children():
		if child.has_method("__lua_load_library"):
			child.__lua_load_library(vm)

	# Expose a custom require function since Luau does not come with packages module
	vm.lua_pushcallable(_require)
	vm.lua_setglobal("require")

	vm.lua_newtable()
	vm.lua_setglobal("__modules")

	# Add property getters and setters to the object metatable
	vm.luaL_getmetatable("object")
	vm.lua_pushcallable(_lua_index)
	vm.lua_rawsetfield(-2, "__index")
	vm.lua_pushcallable(_lua_newindex)
	vm.lua_rawsetfield(-2, "__newindex")
	vm.lua_pushcallable(_lua_call)
	vm.lua_rawsetfield(-2, "__call")
	vm.lua_pop(1)

	add_child(vm)

func _resolve_module_path(module_path: String):
	var module_file_path = module_path.replace(".", "/") + ".lua"
	# TODO Would be good to register locators from outside -core
	var scripts_dir_path = Selene.path(GlobalPaths.server_scripts_dir).path_join(module_file_path)
	if FileAccess.file_exists(scripts_dir_path):
		return scripts_dir_path
	var bundle_script_path = Selene.path(GlobalPaths.bundles_dir).path_join(module_file_path)
	if FileAccess.file_exists(bundle_script_path):
		return bundle_script_path
	return null

func load_module(module_path: String):
	var regex = RegEx.create_from_string("^[a-z0-9_.-]+$")
	if not regex.search(module_path):
		push_error("Invalid module path '%s'. Only letters, numbers, underscores, periods and hyphens are allowed." % module_path)
		return
	var top_before = vm.lua_gettop()
	if vm.lua_dostring('require("%s")' % module_path) == vm.LUA_OK:
		var top_after = vm.lua_gettop()
		var nret = top_after - top_before
		if nret > 0:
			vm.lua_pop(nret)
	else:
		var error = vm.lua_tostring(-1)
		Selene.log_error("Lua Error: %s" % error)
		vm.lua_pop(1)
		return 0


func _require(pvm: LuauVM):
	var module_path = pvm.luaL_checkstring(-1)
	pvm.lua_getglobal("__modules")
	pvm.lua_getfield(-1, module_path)
	if not pvm.lua_isnil(-1):
		return 1
	pvm.lua_pop(2)
	
	var file_path = _resolve_module_path(module_path)
	if not file_path:
		Selene.log_error("Module not found: %s" % module_path)
		return 0
	var script = FileAccess.get_file_as_string(file_path)
	if pvm.lua_dostring(script) == pvm.LUA_OK:
		pvm.lua_getglobal("__modules")
		pvm.lua_pushvalue(-2)
		pvm.lua_setfield(-2, module_path)
		pvm.lua_pop(1)
		return 1
	else:
		var error = pvm.lua_tostring(-1)
		Selene.log_error("Lua Error: %s" % error)
		pvm.lua_pop(1)
		return 0

func _lua_index(pvm: LuauVM):
	var node = pvm.lua_toobject(1)
	var key = pvm.luaL_checkstring(2)
	var value = null
	if node.has_method("_lua_" + key):
		pvm.lua_pushcallable(node.get("_lua_" + key))
		return 1
	if node.has_method("__lua_get_" + key):
		return node.call("__lua_get_" + key, pvm)
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
	if node.has_method("__lua_set_" + key):
		node.call("__lua_set_" + key, pvm)
		return
	var value = pvm.lua_tovariant(3)
	if node.get(key) is Color:
		value = pvm.luaL_checkvector(3)
		value = Color(value.x, value.y, value.z, value.w)
	else:
		value = pvm.lua_tovariant(3)
	node.set(key, value)
	return 0

func _lua_call(pvm: LuauVM):
	var node = pvm.lua_toobject(1)
	if node.has_method("__lua_call"):
		return node.call("__lua_call", pvm)
	return 0

func _on_vm_stdout(message: String):
	script_printed.emit(message)
