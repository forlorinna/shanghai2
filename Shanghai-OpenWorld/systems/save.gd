extends RefCounted

const FILE := "user://shanghai-save.json"
const BACKUP := "user://shanghai-save.backup.json"
const TEMP := "user://shanghai-save.tmp.json"
const VERSION := 1

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var result: Variant = parser.data
	if not result is Dictionary or int(result.get("version", 0)) != VERSION:
		return {}
	var coords: Variant = result.get("position")
	if not coords is Array or coords.size() != 3:
		return {}
	for value in coords:
		if not (value is int or value is float) or not is_finite(float(value)):
			return {}
	for key in ["settings", "vehicle", "mission"]:
		if result.has(key) and not result[key] is Dictionary:
			return {}
	return result

static func read() -> Dictionary:
	var result := _read(FILE)
	return _read(BACKUP) if result.is_empty() else result

static func write(data: Dictionary) -> Error:
	data["version"] = VERSION
	var out := FileAccess.open(TEMP, FileAccess.WRITE)
	if not out:
		return FileAccess.get_open_error()
	out.store_string(JSON.stringify(data))
	out.flush()
	out.close()
	if not _read(FILE).is_empty():
		var backup := DirAccess.copy_absolute(FILE, BACKUP)
		if backup != OK:
			return backup
	return DirAccess.rename_absolute(TEMP, FILE)
