class_name GreabyQrCode
extends Node


enum Encodings {NUMERIC, ALPHANUMERIC, KANJI, BYTES}

enum ErrorCorrectionLevel {
	LOW = 0,
	MEDIUM = 1,
	QUARTILE = 2,
	HIGH = 3,
}

const ERROR_CORRECT_LEVEL_BITS = {
	ErrorCorrectionLevel.LOW: 1,
	ErrorCorrectionLevel.MEDIUM: 0,
	ErrorCorrectionLevel.QUARTILE: 3,
	ErrorCorrectionLevel.HIGH: 2,
}

const MAX_CAPACITY = {
	ErrorCorrectionLevel.LOW: [
		19, 34, 55, 80, 108, 136, 156, 194, 232, 274, 324, 370, 428, 461, 523, 589,
		647, 721, 795, 861, 932, 1006, 1094, 1174, 1276, 1370, 1468, 1531, 1631,
		1735, 1843, 1955, 2071, 2191, 2306, 2434, 2566, 2702, 2812, 2956,
	],
	ErrorCorrectionLevel.MEDIUM: [
		16, 28, 44, 64, 86, 108, 124, 154, 182, 216, 254, 290, 334, 365, 415, 453,
		507, 563, 627, 669, 714, 782, 860, 914, 1000, 1062, 1128, 1193, 1267,
		1373, 1455, 1541, 1631, 1725, 1812, 1914, 1992, 2102, 2216, 2334,
	],
	ErrorCorrectionLevel.QUARTILE: [
		13, 22, 34, 48, 62, 76, 88, 110, 132, 154, 180, 206, 244, 261, 295, 325,
		367, 397, 445, 485, 512, 568, 614, 664, 718, 754, 808, 871, 911, 985,
		1033, 1115, 1171, 1231, 1286, 1354, 1426, 1502, 1582, 1666,
	],
	ErrorCorrectionLevel.HIGH: [
		9, 16, 26, 36, 46, 60, 66, 86, 100, 122, 140, 158, 180, 197, 223, 253,
		283, 313, 341, 385, 406, 442, 464, 514, 538, 596, 628, 661, 701, 745,
		793, 845, 901, 961, 986, 1054, 1096, 1142, 1222, 1276,
	],
}

const LENGTH_INFO_BITS = {
	Encodings.NUMERIC: [10, 12, 14],
	Encodings.ALPHANUMERIC: [9, 11, 13],
	Encodings.KANJI: [8, 10, 12],
	Encodings.BYTES: [8, 16, 16],
}

const ENCODING_INFO_BITS = {
	Encodings.NUMERIC: [false, false, false, true],
	Encodings.ALPHANUMERIC: [false, false, true, false],
	Encodings.KANJI: [true, false, false, false],
	Encodings.BYTES: [false, true, false, false],
}

const ECC_CODEWORDS_PER_BLOCK: Dictionary = {
	ErrorCorrectionLevel.LOW: [
		7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30,
		28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30,
		30, 30, 30, 30, 30,
	],
	ErrorCorrectionLevel.MEDIUM: [
		10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26,
		26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
		28, 28, 28, 28, 28,
	],
	ErrorCorrectionLevel.QUARTILE: [
		13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28,
		26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30,
		30, 30, 30, 30, 30,
	],
	ErrorCorrectionLevel.HIGH: [
		17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28,
		26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
		30, 30, 30, 30, 30,
	],
}

const NUM_ERROR_CORRECTION_BLOCKS: Dictionary = {
	ErrorCorrectionLevel.LOW: [
		1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9,
		10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25,
	],
	ErrorCorrectionLevel.MEDIUM: [
		1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17,
		17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47,
		49,
	],
	ErrorCorrectionLevel.QUARTILE: [
		1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23,
		23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65,
		68,
	],
	ErrorCorrectionLevel.HIGH: [
		1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25,
		25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74,
		77, 81,
	],
}

const ALIGNMENT_PATTERNS = [
	[],
	[6, 18],
	[6, 22],
	[6, 26],
	[6, 30],
	[6, 34],
	[6, 22, 38],
	[6, 24, 42],
	[6, 26, 46],
	[6, 28, 50],
	[6, 30, 54],
	[6, 32, 58],
	[6, 34, 62],
	[6, 26, 46, 66],
	[6, 26, 48, 70],
	[6, 26, 50, 74],
	[6, 30, 54, 78],
	[6, 30, 56, 82],
	[6, 30, 58, 86],
	[6, 34, 62, 90],
	[6, 28, 50, 72, 94],
	[6, 26, 50, 74, 98],
	[6, 30, 54, 78, 102],
	[6, 28, 54, 80, 106],
	[6, 32, 58, 84, 110],
	[6, 30, 58, 86, 114],
	[6, 34, 62, 90, 118],
	[6, 26, 50, 74, 98, 122],
	[6, 30, 54, 78, 102, 126],
	[6, 26, 52, 78, 104, 130],
	[6, 30, 56, 82, 108, 134],
	[6, 34, 60, 86, 112, 138],
	[6, 30, 58, 86, 114, 142],
	[6, 34, 62, 90, 118, 146],
	[6, 30, 54, 78, 102, 126, 150],
	[6, 24, 50, 76, 102, 128, 154],
	[6, 28, 54, 80, 106, 132, 158],
	[6, 32, 58, 84, 110, 136, 162],
	[6, 26, 54, 82, 110, 138, 166],
	[6, 30, 58, 86, 114, 142, 170],
]

const TERMINATOR_BITS = [false, false, false, false]
const PADDING_BITS = [
	[true, true, true, false, true, true, false, false],
	[false, false, false, true, false, false, false, true],
]

var error_correct_level = ErrorCorrectionLevel.LOW
var type_number := 1
var encoding = Encodings.BYTES
var module_count := 0
var modules: Array = []
var qr_data_list: Array = []
var ecc_data_list: Array = []
var qr_data_length := 0


func get_data(input: String) -> Array:
	var mask_pattern := _get_mask_pattern(input)
	return generate(input, mask_pattern)


func get_num_raw_data_modules(version: int) -> int:
	var result := (16 * version + 128) * version + 64
	if version >= 2:
		var alignment_count := floori(float(version) / 7.0) + 2
		result -= (25 * alignment_count - 10) * alignment_count - 55
	if version >= 7:
		result -= 36
	return result


func generate(input: String, mask_pattern: int) -> Array:
	_set_encoding_type(input)
	_encode_data(input)
	_set_minimum_type_number()
	_set_info_segments()
	_split_data_into_blocks()
	_set_error_correction()

	module_count = type_number * 4 + 17
	modules = []
	for row in range(module_count):
		modules.insert(row, [])
		for column in range(module_count):
			modules[row].insert(column, null)

	_set_position_detection_pattern(0, 0)
	_set_position_detection_pattern(module_count - 7, 0)
	_set_position_detection_pattern(0, module_count - 7)
	_set_version_information()
	_set_alignment_pattern()
	_set_timing_pattern()
	_setup_type_info(mask_pattern)

	var zig_zag_positions := _get_data_zigzag_positions()
	_set_data(zig_zag_positions)
	_apply_mask_pattern(mask_pattern, zig_zag_positions)
	return modules


func _set_encoding_type(value: String) -> void:
	var byte_array := value.to_utf8_buffer()
	var is_numeric := true
	for byte in byte_array:
		is_numeric = is_numeric and byte >= 48 and byte <= 57
	if is_numeric:
		encoding = Encodings.NUMERIC
		return

	var is_alphanumeric := true
	for character in value:
		is_alphanumeric = (
			is_alphanumeric
			and GreabyQrUtils.ALPHANUMERIC_CHARACTERS.has(character)
		)
	if is_alphanumeric:
		encoding = Encodings.ALPHANUMERIC
		return
	encoding = Encodings.BYTES


func _encode_data(value: String) -> void:
	qr_data_length = (
		value.to_utf8_buffer().size()
		if encoding == Encodings.BYTES
		else value.length()
	)
	match encoding:
		Encodings.NUMERIC:
			_encode_numeric(value)
		Encodings.ALPHANUMERIC:
			_encode_alphanumeric(value)
		Encodings.BYTES:
			_encode_bytes(value)
		Encodings.KANJI:
			_encode_kanji(value)


func _encode_numeric(value: String) -> void:
	qr_data_list = []
	var data := []
	for index in range(0, ceili(float(value.length()) / 3.0)):
		data.append(value.substr(index * 3, 3).to_int())

	for index in data.size():
		var size := 10
		if data[index] < 100:
			size = 7
		if data[index] < 10:
			size = 4
		qr_data_list.append_array(
			GreabyQrUtils.convert_to_binary(data[index], size)
		)


func _encode_alphanumeric(value: String) -> void:
	qr_data_list = []
	var data: Array = []
	for index in range(0, ceili(float(value.length()) / 2.0)):
		var first_value: int = (
			GreabyQrUtils.ALPHANUMERIC_CHARACTERS[value[index * 2]]
		)
		var second_value := -1
		if index * 2 + 1 < value.length():
			second_value = (
				GreabyQrUtils.ALPHANUMERIC_CHARACTERS[value[index * 2 + 1]]
			)

		var result: Array
		if second_value != -1:
			result = GreabyQrUtils.convert_to_binary(
				first_value * 45 + second_value,
				11
			)
		else:
			result = GreabyQrUtils.convert_to_binary(first_value, 6)
		qr_data_list.append_array(result)


func _encode_bytes(value: String) -> void:
	qr_data_list = []
	for byte in value.to_utf8_buffer():
		qr_data_list.append_array(GreabyQrUtils.convert_to_binary(byte))


func _encode_kanji(_value: String) -> void:
	pass


func _set_minimum_type_number() -> void:
	var encoding_bits_size := len(ENCODING_INFO_BITS[encoding])
	for version in range(1, 41):
		var length_bits_size := _get_length_bits_size(version)
		var total_bits_size: int = (
			encoding_bits_size + length_bits_size + qr_data_list.size()
		)
		var total_bytes_size := ceili(float(total_bits_size) / 8.0)
		if total_bytes_size <= MAX_CAPACITY[error_correct_level][version - 1]:
			type_number = version
			return


func _get_length_bits_size(version: int) -> int:
	var length_bits_size: int = LENGTH_INFO_BITS[encoding][0]
	if version >= 10:
		length_bits_size = LENGTH_INFO_BITS[encoding][1]
	if version >= 27:
		length_bits_size = LENGTH_INFO_BITS[encoding][2]
	return length_bits_size


func _set_info_segments() -> void:
	var length_bits_size := _get_length_bits_size(type_number)
	var length_bits := GreabyQrUtils.convert_to_binary(
		qr_data_length,
		length_bits_size
	)
	qr_data_list = (
		ENCODING_INFO_BITS[encoding]
		+ length_bits
		+ qr_data_list
		+ TERMINATOR_BITS
	)

	var max_capacity: int = MAX_CAPACITY[error_correct_level][type_number - 1]
	if qr_data_list.size() / 8.0 > max_capacity:
		qr_data_list.resize(max_capacity * 8)
		return

	while qr_data_list.size() % 8 != 0:
		qr_data_list.append(false)

	var padding_bits: Array = PADDING_BITS.duplicate(true)
	while qr_data_list.size() / 8 < max_capacity:
		qr_data_list.append_array(padding_bits[0])
		padding_bits.reverse()


func _split_data_into_blocks() -> void:
	var block_count: int = (
		NUM_ERROR_CORRECTION_BLOCKS[error_correct_level][type_number - 1]
	)
	var block_ecc_length: int = (
		ECC_CODEWORDS_PER_BLOCK[error_correct_level][type_number - 1]
	)
	var raw_codewords := floori(float(get_num_raw_data_modules(type_number)) / 8.0)
	var short_block_count := block_count - raw_codewords % block_count
	var short_block_length := floori(float(raw_codewords) / float(block_count))

	var result := []
	var offset := 0
	for block_index in range(block_count):
		var end := (
			offset
			+ (
				short_block_length
				- block_ecc_length
				+ int(block_index >= short_block_count)
			)
			* 8
		)
		result.push_back(qr_data_list.slice(offset, end))
		offset = end
	qr_data_list = result


func _set_error_correction() -> void:
	ecc_data_list = []
	var block_ecc_length: int = (
		ECC_CODEWORDS_PER_BLOCK[error_correct_level][type_number - 1]
	)
	var generator := GreabyQrReedSolomonGenerator.new(block_ecc_length)

	for block_index in range(qr_data_list.size()):
		ecc_data_list.append([])
		var byte_index := -1
		var block_bytes := []
		for index in qr_data_list[block_index].size():
			if index % 8 == 0:
				byte_index += 1
				block_bytes.append([])
			block_bytes[byte_index].append(qr_data_list[block_index][index])

		for index in block_bytes.size():
			block_bytes[index] = GreabyQrUtils.convert_to_decimal(
				block_bytes[index]
			)
		block_bytes = generator.get_remainder(block_bytes)
		for byte in block_bytes:
			ecc_data_list[block_index].append_array(
				GreabyQrUtils.convert_to_binary(byte, 8)
			)
	generator.free()


func _apply_mask_pattern(mask_pattern: int, positions: Array) -> void:
	for position in positions:
		var invert := false
		match mask_pattern:
			0:
				invert = int(position.x + position.y) % 2 == 0
			1:
				invert = int(position.y) % 2 == 0
			2:
				invert = int(position.x) % 3 == 0
			3:
				invert = int(position.x + position.y) % 3 == 0
			4:
				invert = (
					int(floor(position.x / 3) + floor(position.y / 2)) % 2 == 0
				)
			5:
				invert = (
					int(position.x * position.y) % 2
					+ int(position.x * position.y) % 3
					== 0
				)
			6:
				invert = (
					(
						int(position.x * position.y) % 2
						+ int(position.x * position.y) % 3
					)
					% 2
					== 0
				)
			7:
				invert = (
					(
						int(position.x + position.y) % 2
						+ int(position.x * position.y) % 3
					)
					% 2
					== 0
				)
		if invert:
			modules[position.x][position.y] = not modules[position.x][position.y]


func _get_mask_pattern(input: String) -> int:
	var minimum_lost_point := 0
	var pattern := 0
	for index in range(8):
		generate(input, index)
		var lost_point := get_lost_point()
		if index == 0 or minimum_lost_point > lost_point:
			minimum_lost_point = lost_point
			pattern = index
	return pattern


func _set_position_detection_pattern(row: int, column: int) -> void:
	for row_offset in range(-1, 8):
		for column_offset in range(-1, 8):
			if (
				row + row_offset <= -1
				or module_count <= row + row_offset
				or column + column_offset <= -1
				or module_count <= column + column_offset
			):
				continue
			modules[row + row_offset][column + column_offset] = (
				(
					0 <= row_offset
					and row_offset <= 6
					and (column_offset == 0 or column_offset == 6)
				)
				or (
					0 <= column_offset
					and column_offset <= 6
					and (row_offset == 0 or row_offset == 6)
				)
				or (
					2 <= row_offset
					and row_offset <= 4
					and 2 <= column_offset
					and column_offset <= 4
				)
			)


func _set_alignment_pattern() -> void:
	var patterns: Array = ALIGNMENT_PATTERNS[type_number - 1]
	for row in patterns:
		for column in patterns:
			if modules[row][column] != null:
				continue
			for row_offset in range(-2, 3):
				for column_offset in range(-2, 3):
					modules[row + row_offset][column + column_offset] = (
						row_offset == -2
						or row_offset == 2
						or column_offset == -2
						or column_offset == 2
						or (row_offset == 0 and column_offset == 0)
					)


func _set_timing_pattern() -> void:
	for index in range(8, module_count - 8):
		if modules[index][6] == null:
			modules[index][6] = index % 2 == 0
		if modules[6][index] == null:
			modules[6][index] = index % 2 == 0


func _set_version_information() -> void:
	if type_number < 7:
		return

	var remainder := type_number
	for _index in range(12):
		remainder = (remainder << 1) ^ ((remainder >> 11) * 0x1F25)
	var bits := type_number << 12 | remainder

	for index in range(18):
		var dark := ((bits >> index) & 1) != 0
		var first := modules.size() - 11 + index % 3
		var second := floori(float(index) / 3.0)
		modules[first][second] = dark
		modules[second][first] = dark


func _setup_type_info(mask_pattern: int) -> void:
	var data: int = ERROR_CORRECT_LEVEL_BITS[error_correct_level] << 3 | mask_pattern
	var remainder := data
	for _index in range(10):
		remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537)
	var bits := (data << 10 | remainder) ^ 0x5412

	for index in range(6):
		modules[8][index] = ((bits >> index) & 1) == 1
	modules[8][7] = ((bits >> 6) & 1) == 1
	modules[8][8] = ((bits >> 7) & 1) == 1
	modules[7][8] = ((bits >> 8) & 1) == 1

	for index in range(9, 15):
		modules[14 - index][8] = ((bits >> index) & 1) == 1
	for index in range(8):
		modules[modules.size() - 1 - index][8] = ((bits >> index) & 1) == 1
	for index in range(8, 15):
		modules[8][modules.size() - 15 + index] = ((bits >> index) & 1) == 1
	modules[8][modules.size() - 8] = true


func get_lost_point() -> int:
	var lost_point := 0
	for row in range(module_count):
		for column in range(module_count):
			var same_count := 0
			var dark: Variant = modules[row][column]
			for row_offset in range(-1, 2):
				if row + row_offset < 0 or module_count <= row + row_offset:
					continue
				for column_offset in range(-1, 2):
					if (
						column + column_offset < 0
						or module_count <= column + column_offset
					):
						continue
					if row_offset == 0 and column_offset == 0:
						continue
					if dark == modules[row + row_offset][column + column_offset]:
						same_count += 1
			if same_count > 5:
				lost_point += 3 + same_count - 5

	for row in range(module_count - 1):
		for column in range(module_count - 1):
			var dark_count := 0
			if modules[row][column]:
				dark_count += 1
			if modules[row + 1][column]:
				dark_count += 1
			if modules[row][column + 1]:
				dark_count += 1
			if modules[row + 1][column + 1]:
				dark_count += 1
			if dark_count == 0 or dark_count == 4:
				lost_point += 3

	for row in range(module_count):
		for column in range(module_count - 10):
			if _is_finder_like_row(row, column):
				lost_point += 40
	for column in range(module_count):
		for row in range(module_count - 10):
			if _is_finder_like_column(row, column):
				lost_point += 40

	var total_dark := 0
	for column in range(module_count):
		for row in range(module_count):
			if modules[row][column]:
				total_dark += 1
	var ratio := (
		absf(100.0 * total_dark / module_count / module_count - 50.0) / 5.0
	)
	lost_point += int(ratio * 10.0)
	return lost_point


func _is_finder_like_row(row: int, column: int) -> bool:
	return (
		modules[row][column]
		and not modules[row][column + 1]
		and modules[row][column + 2]
		and modules[row][column + 3]
		and modules[row][column + 4]
		and not modules[row][column + 5]
		and modules[row][column + 6]
		and not modules[row][column + 7]
		and not modules[row][column + 8]
		and not modules[row][column + 9]
		and not modules[row][column + 10]
	)


func _is_finder_like_column(row: int, column: int) -> bool:
	return (
		modules[row][column]
		and not modules[row + 1][column]
		and modules[row + 2][column]
		and modules[row + 3][column]
		and modules[row + 4][column]
		and not modules[row + 5][column]
		and modules[row + 6][column]
		and not modules[row + 7][column]
		and not modules[row + 8][column]
		and not modules[row + 9][column]
		and not modules[row + 10][column]
	)


func _get_data_zigzag_positions() -> Array:
	var result := []
	for row in range(modules.size() - 1, 1, -2):
		if row <= 6:
			row -= 1
		for column in range(0, modules.size()):
			for index in range(0, 2):
				var position := Vector2i(row - index, column)
				if ((row + 1) & 2) == 0:
					position.y = modules.size() - 1 - column
				if modules[position.x][position.y] == null:
					result.append(position)
	return result


func _set_data(zig_zag_positions: Array) -> void:
	var position_index := 0
	for index in qr_data_list[qr_data_list.size() - 1].size() / 8:
		for row in qr_data_list.size():
			if qr_data_list[row].size() > index * 8:
				for bit in range(8):
					var position: Vector2i = zig_zag_positions[position_index]
					modules[position.x][position.y] = (
						qr_data_list[row][index * 8 + bit]
					)
					position_index += 1

	for index in ecc_data_list[0].size() / 8:
		for row in ecc_data_list.size():
			if ecc_data_list[row].size() > index * 8:
				for bit in range(8):
					var position: Vector2i = zig_zag_positions[position_index]
					modules[position.x][position.y] = (
						ecc_data_list[row][index * 8 + bit]
					)
					position_index += 1

	while position_index < zig_zag_positions.size():
		var position: Vector2i = zig_zag_positions[position_index]
		modules[position.x][position.y] = false
		position_index += 1
