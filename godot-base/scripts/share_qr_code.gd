class_name ShareQrCode
extends RefCounted

## CPU-only QR generation for share cards. The vendored encoder is MIT
## licensed; this wrapper owns URL validation and scan-safe image rendering.

const ENCODER_SCRIPT := preload("res://third_party/greaby_qrcode/qr_code.gd")
const DEFAULT_IMAGE_SIZE := 222
const QUIET_ZONE_MODULES := 4
const MAX_URL_BYTES := 42
const LIGHT_COLOR := Color("f7fbfc")
const DARK_COLOR := Color("10191e")


static func validation_error(raw_url: String) -> String:
	var url := raw_url.strip_edges()
	if url.is_empty():
		return "The share image needs a stats URL for its QR code."
	if not url.begins_with("https://") and not url.begins_with("http://"):
		return "The share stats URL must begin with http:// or https://."
	for index in range(url.length()):
		var codepoint := url.unicode_at(index)
		if codepoint < 0x21 or codepoint > 0x7E:
			return "The share stats URL must use printable ASCII characters."
	if _host_from_url(url).is_empty():
		return "The share stats URL must include a host."
	if url.to_utf8_buffer().size() > MAX_URL_BYTES:
		return "The share stats URL is too long for a reliable QR code."
	return ""


static func _host_from_url(url: String) -> String:
	var authority_start := url.find("://") + 3
	var authority_end := url.length()
	for separator in ["/", "?", "#"]:
		var separator_index := url.find(separator, authority_start)
		if separator_index >= 0:
			authority_end = mini(authority_end, separator_index)

	var authority := url.substr(
		authority_start,
		authority_end - authority_start
	)
	var credentials_end := authority.rfind("@")
	if credentials_end >= 0:
		authority = authority.substr(credentials_end + 1)
	if authority.begins_with("["):
		var bracket_end := authority.find("]")
		return authority.substr(0, bracket_end + 1) if bracket_end > 1 else ""
	return authority.get_slice(":", 0).strip_edges()


static func create_texture(
	url: String,
	image_size := DEFAULT_IMAGE_SIZE
) -> ImageTexture:
	var image := create_image(url, image_size)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


static func create_image(
	url: String,
	image_size := DEFAULT_IMAGE_SIZE
) -> Image:
	if not validation_error(url).is_empty() or image_size <= 0:
		return null

	var encoder := ENCODER_SCRIPT.new()
	encoder.error_correct_level = ENCODER_SCRIPT.ErrorCorrectionLevel.MEDIUM
	var modules: Array = encoder.get_data(url.strip_edges())
	encoder.free()
	if modules.is_empty() or modules.size() != modules[0].size():
		return null

	var total_modules := modules.size() + QUIET_ZONE_MODULES * 2
	var module_size := image_size / total_modules
	if module_size < 2:
		return null

	var image := Image.create_empty(
		image_size,
		image_size,
		false,
		Image.FORMAT_RGB8
	)
	image.fill(LIGHT_COLOR)

	var rendered_size := total_modules * module_size
	var first_module := (
		Vector2i.ONE * ((image_size - rendered_size) / 2)
		+ Vector2i.ONE * QUIET_ZONE_MODULES * module_size
	)
	for module_x in range(modules.size()):
		for module_y in range(modules[module_x].size()):
			if not bool(modules[module_x][module_y]):
				continue
			image.fill_rect(
				Rect2i(
					first_module
					+ Vector2i(module_x, module_y) * module_size,
					Vector2i.ONE * module_size
				),
				DARK_COLOR
			)
	return image
