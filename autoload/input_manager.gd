## input_manager.gd
## Programmatic InputMap setup. Registering input actions in code (instead
## of editing the [input] section of project.godot directly) survives the
## editor's project-settings autoformatter and keeps gamepad bindings
## versioned alongside the rest of the source.
##
## Autoloaded as `InputManager`. Runs once at startup; all other systems
## just call Input.is_action_pressed("rimvale_inventory") etc.
##
## Keyboard bindings preserve the WASD / arrow-keys / Enter conventions
## the game already used. Gamepad bindings target an Xbox-style controller
## (which is what Steam Input remaps every other controller to anyway).

extends Node

# Xbox/Steam Input controller button mapping (JoyButton enum):
#   A=0 B=1 X=2 Y=3 LB=9 RB=10 Back=4 Start=6 LS=7 RS=8
#   DPad: Up=11 Down=12 Left=13 Right=14
const _JOY_A     := JOY_BUTTON_A
const _JOY_B     := JOY_BUTTON_B
const _JOY_X     := JOY_BUTTON_X
const _JOY_Y     := JOY_BUTTON_Y
const _JOY_LB    := JOY_BUTTON_LEFT_SHOULDER
const _JOY_RB    := JOY_BUTTON_RIGHT_SHOULDER
const _JOY_BACK  := JOY_BUTTON_BACK
const _JOY_START := JOY_BUTTON_START
const _JOY_DU    := JOY_BUTTON_DPAD_UP
const _JOY_DD    := JOY_BUTTON_DPAD_DOWN
const _JOY_DL    := JOY_BUTTON_DPAD_LEFT
const _JOY_DR    := JOY_BUTTON_DPAD_RIGHT

const STICK_DEADZONE := 0.5


func _ready() -> void:
	# These are built-in Godot UI actions — make sure they ALSO accept gamepad
	# input (Godot adds keyboard defaults; we add controller).
	_add_joy_button("ui_accept",  _JOY_A)
	_add_joy_button("ui_cancel",  _JOY_B)

	# Movement / UI navigation: D-pad + left stick + arrow keys. Godot's
	# defaults already cover arrow keys and D-pad; we additionally add the
	# analog stick.
	# NOTE: WASD is deliberately NOT bound to ui_* — it's the camera-pan
	# control on battle and region maps. Binding it here made W/A/S/D move
	# keyboard focus between UI buttons instead of panning whenever any
	# button had focus (e.g. right after clicking an action).
	_add_joy_axis("ui_up",    JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("ui_down",  JOY_AXIS_LEFT_Y,  1.0)
	_add_joy_axis("ui_left",  JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("ui_right", JOY_AXIS_LEFT_X,  1.0)
	_add_joy_button("ui_up",    _JOY_DU)
	_add_joy_button("ui_down",  _JOY_DD)
	_add_joy_button("ui_left",  _JOY_DL)
	_add_joy_button("ui_right", _JOY_DR)

	# Custom Rimvale actions.
	# Menu (Esc / Start button) — back-out / pause-menu equivalent.
	_make("rimvale_menu", [
		[KEY_ESCAPE],
		[_JOY_START, true],
	])
	# Inventory (I / Y button).
	_make("rimvale_inventory", [
		[KEY_I],
		[_JOY_Y, true],
	])
	# Settings (F10 / Back button).
	_make("rimvale_settings", [
		[KEY_F10],
		[_JOY_BACK, true],
	])
	# Camera yaw — Q/E on keyboard, LB/RB on gamepad. Region map already
	# accepted Q/E; the gamepad bindings are additive.
	_make("rimvale_camera_left", [
		[KEY_Q],
		[_JOY_LB, true],
	])
	_make("rimvale_camera_right", [
		[KEY_E],
		[_JOY_RB, true],
	])
	# Confirm interaction (Space / A button) — distinct from ui_accept so
	# we can keep ui_accept tied to the UI focus system.
	_make("rimvale_interact", [
		[KEY_SPACE],
		[_JOY_A, true],
	])

	# Make sure every gamepad-tagged action has the deadzone set to a
	# sensible value.
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_") or str(action).begins_with("rimvale_"):
			InputMap.action_set_deadzone(action, STICK_DEADZONE)


# ──────────────────────────────────────────────────────────────────────────────
# Helpers — concise builders
# ──────────────────────────────────────────────────────────────────────────────
func _make(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	for spec in events:
		var arr: Array = spec
		if arr.size() == 0: continue
		if arr.size() == 1:
			_add_key(action, int(arr[0]))
		else:
			# [button_index, is_joy_button]
			if bool(arr[1]):
				_add_joy_button(action, int(arr[0]))
			else:
				_add_key(action, int(arr[0]))


func _add_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	# Avoid duplicates if the project.godot file already declared one.
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).keycode == keycode:
			return
	var k := InputEventKey.new()
	k.keycode = keycode
	InputMap.action_add_event(action, k)


func _add_joy_button(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return
	var b := InputEventJoypadButton.new()
	b.button_index = button
	InputMap.action_add_event(action, b)


func _add_joy_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			var m := ev as InputEventJoypadMotion
			if m.axis == axis and signf(m.axis_value) == signf(value):
				return
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = value
	InputMap.action_add_event(action, m)
