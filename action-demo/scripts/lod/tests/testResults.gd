class_name TestResult
extends RefCounted

var test_name: String = ""
var passed: bool = false
var duration_ms: float = 0.0
var message: String = ""


func _init(
	_name: String = "",
	_passed: bool = false,
	_duration: float = 0.0,
	_message: String = ""
) -> void:
	test_name = _name
	passed = _passed
	duration_ms = _duration
	message = _message
