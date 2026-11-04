extends Node
## Global player settings (autoload "Settings").
##
## Classic approach: a second singleton for persisted preferences. Each setting
## needs its own property, signal, bus mapping and save/load code.

signal music_volume_changed(new_volume: float)
signal sfx_volume_changed(new_volume: float)

const SAVE_PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

var music_volume: float = 0.8:
	set(new_value):
		new_value = clampf(new_value, 0.0, 1.0)
		if is_equal_approx(new_value, music_volume):
			return
		music_volume = new_value
		_apply_bus_volume(MUSIC_BUS, music_volume)
		music_volume_changed.emit(music_volume)
		_save()

var sfx_volume: float = 0.8:
	set(new_value):
		new_value = clampf(new_value, 0.0, 1.0)
		if is_equal_approx(new_value, sfx_volume):
			return
		sfx_volume = new_value
		_apply_bus_volume(SFX_BUS, sfx_volume)
		sfx_volume_changed.emit(sfx_volume)
		_save()

var _loading := false


func _ready() -> void:
	_load()
	_apply_bus_volume(MUSIC_BUS, music_volume)
	_apply_bus_volume(SFX_BUS, sfx_volume)


func _apply_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear_volume, 0.0001)))


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	_loading = true
	music_volume = float(config.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(config.get_value("audio", "sfx_volume", sfx_volume))
	_loading = false


func _save() -> void:
	if _loading:
		return
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SAVE_PATH)
