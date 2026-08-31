class_name GreabyQrReedSolomonGenerator
extends Node


var coefficients: Array = []


func _init(degree: int) -> void:
	if degree < 1 or degree > 255:
		push_error("Degree out of range")

	for _index in range(0, degree - 1):
		coefficients.append(0)
	coefficients.append(1)

	var root := 1
	for _index in range(0, degree):
		for coefficient_index in range(0, coefficients.size()):
			coefficients[coefficient_index] = _multiply(
				coefficients[coefficient_index],
				root
			)
			if coefficient_index + 1 < coefficients.size():
				coefficients[coefficient_index] ^= coefficients[coefficient_index + 1]
		root = _multiply(root, 0x02)


func get_remainder(data: Array) -> Array:
	var result: Array = []
	for _index in coefficients.size():
		result.append(0)

	for byte in data:
		var factor: int = byte ^ result.pop_front()
		result.append(0)
		for index in coefficients.size():
			result[index] ^= _multiply(coefficients[index], factor)
	return result


func _multiply(x: int, y: int) -> int:
	if (x >> 8) != 0 or (y >> 8) != 0:
		push_error("Byte out of range")

	var result := 0
	for index in range(7, -1, -1):
		result = (result << 1) ^ ((result >> 7) * 0x11D)
		result ^= ((y >> index) & 1) * x

	if (result >> 8) != 0:
		push_error("Assertion error")
	return result
