class_name BundleManifestLoader
extends Node

signal script_printed(message: String)
signal manifest_error(bundle_id: String, message: String)

func load_manifest(bundle_id: String) -> BundleManifest:
	var vm = LuauVM.new()
	vm.stdout.connect(_on_vm_stdout)
	vm.open_all_libraries()
	add_child(vm)
	var manifest = BundleManifest.new()
	manifest.id = bundle_id
	manifest.name = bundle_id
	var manifest_path = Selene.path(GlobalPaths.bundles_dir).path_join(bundle_id).path_join("bundle.lua")
	if FileAccess.file_exists(manifest_path):
		if not _evaluate_script(vm, bundle_id, manifest_path):
			return null
		if not _apply_manifest(vm, manifest):
			return null
	vm.queue_free()
	return manifest

func _evaluate_script(vm: LuauVM, bundle_id: String, path: String):
	var script = FileAccess.get_file_as_string(path)
	if vm.lua_dostring(script) != vm.LUA_OK:
		var error = vm.lua_tostring(-1)
		manifest_error.emit(bundle_id, error)
		vm.lua_pop(1)
		return false
	return true

func _apply_manifest(vm: LuauVM, manifest: BundleManifest):
	vm.lua_getglobal("name")
	if not vm.lua_isnil(-1):
		manifest.name = vm.luaL_checkstring(-1)
	else:
		manifest.name = manifest.id
	if not manifest.name:
		manifest_error.emit(manifest.id, "Invalid name in manifest for bundle %s" % manifest.id)
	vm.lua_pop(1)
	
	vm.lua_getglobal("client_entrypoints")
	if not vm.lua_isnil(-1):
		var entrypoints = vm.lua_toarray(1)
		for entrypoint in entrypoints:
			if entrypoint is String:
				manifest.client_entrypoints.append(entrypoint)
	vm.lua_pop(1)
	
	vm.lua_getglobal("server_entrypoints")
	if not vm.lua_isnil(-1):
		var entrypoints = vm.lua_toarray(1)
		for entrypoint in entrypoints:
			if entrypoint is String:
				manifest.server_entrypoints.append(entrypoint)
	vm.lua_pop(1)

	return true

func _on_vm_stdout(message: String):
	script_printed.emit(message)