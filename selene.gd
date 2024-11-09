class_name Selene

static var base_dir = "user://"
static var debug_hash_dump = true

static func path(p_path: String) -> String:
	if p_path.begins_with("run://"):
		return base_dir.path_join(p_path.trim_prefix("run://"))
	return p_path

static func globalize_path(p_path: String) -> String:
	var intermediate: String = path(p_path)
	if not OS.has_feature("editor") and intermediate.begins_with("res://"):
		return OS.get_executable_path().get_base_dir().path_join(intermediate.trim_prefix("res://"))
	else:
		return ProjectSettings.globalize_path(intermediate)
