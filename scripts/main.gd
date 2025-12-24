extends Control

# 螃蟹打击解压桌宠 - 操作说明：
# 左键：点击螃蟹进行打击
# 右键：短按显示菜单，拖拽移动桌宠位置
# Ctrl+ESC：关闭程序

# 螃蟹状态枚举
enum CrabState {
	HEALTHY,      # 健康状态
	CRACKED,      # 出现裂缝  
	DAMAGED,      # 严重损坏
	DYING,        # 垂死状态
	DEAD          # 死亡状态
}

# 眼神状态枚举
enum EyeState {
	THREATENING,  # 威胁性眼神
	WEAKENING,    # 力不从心
	DYING,        # 垂死
	DEAD,         # 死亡
	CLICKED       # 被点击时的表情 (><)
}

# 游戏变量
var click_count: int = 0
var current_crab_state: CrabState = CrabState.HEALTHY
var current_eye_state: EyeState = EyeState.THREATENING
var is_showing_click_expression: bool = false

# 节点引用
@onready var crab_body: Sprite2D = $CrabContainer/Crab/CrabBody
@onready var crab_eyes: Sprite2D = $CrabContainer/Crab/CrabEyes
@onready var left_claw: Sprite2D = $CrabContainer/Crab/LeftClaw
@onready var right_claw: Sprite2D = $CrabContainer/Crab/RightClaw
@onready var legf1: Sprite2D = $CrabContainer/Crab/LEGF1  # 前右腿（画面左侧）
@onready var legf2: Sprite2D = $CrabContainer/Crab/LEGF2  # 前左腿（画面右侧）
@onready var legb1: Sprite2D = $CrabContainer/Crab/LEGB1  # 后右腿（画面左侧）
@onready var legb2: Sprite2D = $CrabContainer/Crab/LEGB2  # 后左腿（画面右侧）
@onready var click_area: Area2D = $CrabContainer/Crab/ClickArea
@onready var collision_shape: CollisionShape2D = $CrabContainer/Crab/ClickArea/CollisionShape2D
@onready var particle_container: Control = $CrabContainer/ParticleContainer
@onready var debug_label: Label = $DebugLabel
@onready var crab_container: Control = $CrabContainer

# 音效播放器节点引用
var hit_audio_player: AudioStreamPlayer
var broken_audio_player: AudioStreamPlayer
var powerup_audio_player: AudioStreamPlayer

# 身体状态阈值设置（9个身体状态）
var body_state_thresholds = [
	0,   # body1.png - 完全健康
	5,   # body2.png - 轻微裂缝
	10,  # body3.png
	15,  # body4.png
	20,  # body5.png
	25,  # body6.png
	30,  # body7.png
	35,  # body8.png
	40   # body9.png - 最终损坏
]

# 眼神状态阈值设置
var state_thresholds = {
	CrabState.CRACKED: 5,    # 5次点击后出现裂缝
	CrabState.DAMAGED: 15,   # 15次点击后严重损坏
	CrabState.DYING: 25,     # 25次点击后垂死
	CrabState.DEAD: 35       # 35次点击后死亡
}

# 部位掉落阈值（根据您的命名调整）
var part_drop_thresholds = {
	"LEGF1": 8,     # 前右腿（画面左侧）
	"LEGB1": 12,    # 后右腿（画面左侧）
	"LEGF2": 18,    # 前左腿（画面右侧）
	"LEGB2": 22,    # 后左腿（画面右侧）
	"left_claw": 28,   # 左钳子（画面右侧）
	"right_claw": 32   # 右钳子（画面左侧）
}

# 已掉落的部位列表
var dropped_parts: Array[String] = []

# 保存原始位置和偏移数据（从场景文件读取）
var original_positions = {
	"LEGF1": Vector2(41, 64),
	"LEGF2": Vector2(156, 64),
	"LEGB1": Vector2(48, 69),
	"LEGB2": Vector2(151, 69),
	"left_claw": Vector2(144, 72),
	"right_claw": Vector2(48, 72)
}

var original_offsets = {
	"LEGF1": Vector2(55, 0),
	"LEGF2": Vector2(-60, 0),
	"LEGB1": Vector2(48, -5),
	"LEGB2": Vector2(-55, -5),
	"left_claw": Vector2(-48, -8),
	"right_claw": Vector2(48, -8)
}

# 存储部位掉落动画的Tween引用，方便单独控制
var part_drop_tweens = {}

# 拖拽相关变量 - 使用教程推荐的右键拖拽方式
var is_dragging = false
var right_click_start_pos = Vector2.ZERO
var right_click_start_time = 0.0
var drag_threshold = 5.0  # 像素阈值，超过这个距离才算拖拽
var click_time_threshold = 0.5  # 时间阈值，超过这个时间自动进入拖拽模式

# 右键菜单相关
var context_menu: PopupMenu
var is_context_menu_visible = false

# 音效资源
var hit_sounds: Array[AudioStream] = []
var broken_sound: AudioStream
var powerup_sound: AudioStream

func _ready():
	# 等待一帧确保所有初始化完成
	await get_tree().process_frame
	
	# 设置透明背景（桌宠模式必需）- 根据Godot 4.4教程的正确方法
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, 0)
	get_window().set_flag(Window.FLAG_TRANSPARENT, true)
	
	print("透明背景已启用")
	
	# 检查所有节点引用是否正确
	print("开始初始化螃蟹游戏...")
	if not validate_node_references():
		return
	
	# 设置碰撞区域
	setup_collision()
	
	# 连接点击信号
	click_area.input_event.connect(_on_crab_clicked)
	print("Area2D信号已连接")
	
	# 初始化所有部位贴图
	initialize_part_textures()
	
	# 初始化音效系统
	initialize_audio_system()
	
	# 初始化视觉效果
	update_crab_visuals()
	
	# 隐藏调试标签（桌宠模式不需要调试信息）
	debug_label.visible = false
	
	# 创建右键菜单
	create_context_menu()
	
	print("螃蟹游戏初始化完成！")

# 全局输入检测，检测螃蟹的非透明像素
func _input(event):
	# 检测关闭操作：Ctrl+ESC（避免与拖拽冲突）
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.is_key_pressed(KEY_CTRL):
			print("检测到Ctrl+ESC，关闭程序")
			get_tree().quit()
			return
	
	# 点击其他地方隐藏右键菜单
	if event is InputEventMouseButton and event.pressed and is_context_menu_visible:
		print("检测到菜单可见时的点击事件，菜单状态: %s" % is_context_menu_visible)
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("左键点击时菜单可见，隐藏菜单")
			hide_context_menu()
			return
	
	# 鼠标按钮事件处理
	if event is InputEventMouseButton:
		if event.pressed:
			print("全局检测到鼠标点击，位置: %s" % event.position)
			# 检查点击是否在螃蟹区域内
			var local_pos = crab_container.global_position
			var crab_rect = Rect2(local_pos, Vector2(192, 128))
			if crab_rect.has_point(event.position):
				print("点击在螃蟹区域内！")
				var click_local_pos = event.position - local_pos
				
				# 检查点击位置是否在螃蟹的非透明像素上
				print("检查螃蟹点击检测: click_local_pos=%s" % click_local_pos)
				var is_on_crab = is_click_on_crab_sprite(click_local_pos)
				print("is_click_on_crab_sprite返回: %s" % is_on_crab)
				if is_on_crab:
					if event.button_index == MOUSE_BUTTON_LEFT:
						print("点击在螃蟹非透明像素上！")
						handle_crab_click(click_local_pos)
					elif event.button_index == MOUSE_BUTTON_RIGHT:
						# 右键按下：记录开始位置和时间，准备判断是拖拽还是菜单
						print("右键按下在螃蟹非透明像素上！")
						right_click_start_pos = event.position
						right_click_start_time = Time.get_ticks_msec() / 1000.0
						hide_context_menu()  # 隐藏可能存在的菜单
				else:
					print("点击在透明区域，忽略")
		else:
			# 鼠标按钮释放
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if is_dragging:
					print("右键拖拽结束！")
					stop_dragging()
				else:
					# 检查是否应该显示右键菜单
					var current_time = Time.get_ticks_msec() / 1000.0
					var time_diff = current_time - right_click_start_time
					var pos_diff = (event.position - right_click_start_pos).length()
					
					print("右键释放检查: 时间差=%.2f秒, 位置差=%.1f像素" % [time_diff, pos_diff])
					
					# 如果鼠标移动距离小且时间短，显示菜单
					if pos_diff < drag_threshold and time_diff < click_time_threshold:
						print("显示右键菜单")
						# 使用当前鼠标的屏幕绝对位置显示菜单
						var screen_mouse_pos = DisplayServer.mouse_get_position()
						show_context_menu(screen_mouse_pos)
	
	# 鼠标移动事件处理 - 右键拖拽
	elif event is InputEventMouseMotion:
		if is_dragging:
			# 使用DisplayServer获取真正的全局鼠标位置
			var global_mouse_pos = DisplayServer.mouse_get_position()
			handle_dragging(global_mouse_pos)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			# 检查是否应该开始拖拽
			var pos_diff = (event.position - right_click_start_pos).length()
			if pos_diff > drag_threshold:
				print("达到拖拽阈值，开始拖拽")
				start_dragging()

func is_click_on_crab_sprite(click_pos: Vector2) -> bool:
	# 检查点击位置是否在螃蟹的非透明像素上
	# 我们需要检查所有可见的螃蟹部件
	
	# 将点击位置转换为相对于Sprite2D中心的坐标
	var sprite_center = Vector2(96, 64)  # 所有sprite的position
	var relative_pos = click_pos - sprite_center
	
	print("点击检测调试: click_pos=%s, sprite_center=%s, relative_pos=%s" % [click_pos, sprite_center, relative_pos])
	
	# 检查身体贴图
	if crab_body.texture != null and crab_body.visible:
		if is_pixel_solid(crab_body.texture, relative_pos):
			return true
	
	# 检查眼神贴图
	if crab_eyes.texture != null and crab_eyes.visible:
		if is_pixel_solid(crab_eyes.texture, relative_pos):
			return true
	
	# 检查钳子贴图（排除已掉落的部位）
	if left_claw.texture != null and left_claw.visible and "left_claw" not in dropped_parts:
		if is_pixel_solid(left_claw.texture, relative_pos):
			return true
	
	if right_claw.texture != null and right_claw.visible and "right_claw" not in dropped_parts:
		if is_pixel_solid(right_claw.texture, relative_pos):
			return true
	
	# 检查腿部贴图（排除已掉落的部位）
	if legf1.texture != null and legf1.visible and "LEGF1" not in dropped_parts:
		if is_pixel_solid(legf1.texture, relative_pos):
			return true
	
	if legf2.texture != null and legf2.visible and "LEGF2" not in dropped_parts:
		if is_pixel_solid(legf2.texture, relative_pos):
			return true
	
	if legb1.texture != null and legb1.visible and "LEGB1" not in dropped_parts:
		if is_pixel_solid(legb1.texture, relative_pos):
			return true
	
	if legb2.texture != null and legb2.visible and "LEGB2" not in dropped_parts:
		if is_pixel_solid(legb2.texture, relative_pos):
			return true
	
	return false

func is_pixel_solid(texture: Texture2D, pos: Vector2) -> bool:
	# 检查贴图指定位置的像素是否为非透明
	if texture == null:
		return false
	
	# 将位置转换为贴图坐标系（中心为原点转换为左上角为原点）
	var texture_size = texture.get_size()
	var texture_pos = pos + texture_size / 2
	
	# 检查坐标是否在贴图范围内
	if texture_pos.x < 0 or texture_pos.x >= texture_size.x or texture_pos.y < 0 or texture_pos.y >= texture_size.y:
		return false
	
	# 获取贴图的Image对象
	var image = texture.get_image()
	if image == null:
		return false
	
	# 获取像素颜色
	var pixel_color = image.get_pixel(int(texture_pos.x), int(texture_pos.y))
	
	# 检查alpha通道，如果大于0.1就认为是非透明
	return pixel_color.a > 0.1

func validate_node_references() -> bool:
	# 验证所有重要节点引用
	var nodes_to_check = {
		"crab_body": crab_body,
		"crab_eyes": crab_eyes,
		"left_claw": left_claw,
		"right_claw": right_claw,
		"legf1": legf1,
		"legf2": legf2,
		"legb1": legb1,
		"legb2": legb2,
		"click_area": click_area,
		"collision_shape": collision_shape,
		"particle_container": particle_container,
		"debug_label": debug_label,
		"crab_container": crab_container
	}
	
	for node_name in nodes_to_check:
		if nodes_to_check[node_name] == null:
			push_error("节点引用失败: " + node_name)
			return false
		else:
			print("节点 %s 引用成功" % node_name)
	
	return true

func initialize_part_textures():
	# 加载所有部位的贴图，并检查加载是否成功
	var texture_paths = {
		"left_claw": "res://textures/left_claw.png",
		"right_claw": "res://textures/right_claw.png",
		"legf1": "res://textures/LEGF1.png",
		"legf2": "res://textures/LEGF2.png",
		"legb1": "res://textures/LEGB1.png",
		"legb2": "res://textures/LEGB2.png"
	}
	
	for part_name in texture_paths:
		var texture_path = texture_paths[part_name]
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			match part_name:
				"left_claw":
					left_claw.texture = texture
				"right_claw":
					right_claw.texture = texture
				"legf1":
					legf1.texture = texture
				"legf2":
					legf2.texture = texture
				"legb1":
					legb1.texture = texture
				"legb2":
					legb2.texture = texture
			print("加载贴图成功: %s" % texture_path)
		else:
			push_warning("贴图文件不存在: %s" % texture_path)

func initialize_audio_system():
	# 创建音效播放器节点
	hit_audio_player = AudioStreamPlayer.new()
	broken_audio_player = AudioStreamPlayer.new()
	powerup_audio_player = AudioStreamPlayer.new()
	
	# 添加到场景树
	add_child(hit_audio_player)
	add_child(broken_audio_player)
	add_child(powerup_audio_player)
	
	# 加载点击音效（hitHurt1、2、3）
	var hit_sound_paths = [
		"res://sounds/hitHurt1.wav",
		"res://sounds/hitHurt2.wav", 
		"res://sounds/hitHurt3.wav"
	]
	
	for sound_path in hit_sound_paths:
		if ResourceLoader.exists(sound_path):
			var audio_stream = load(sound_path)
			hit_sounds.append(audio_stream)
			print("加载点击音效成功: %s" % sound_path)
		else:
			push_warning("音效文件不存在: %s" % sound_path)
	
	# 加载部位掉落音效
	var broken_sound_path = "res://sounds/hitbroken.wav"
	if ResourceLoader.exists(broken_sound_path):
		broken_sound = load(broken_sound_path)
		print("加载部位掉落音效成功: %s" % broken_sound_path)
	else:
		push_warning("音效文件不存在: %s" % broken_sound_path)
	
	# 加载复活音效
	var powerup_sound_path = "res://sounds/powerUp.wav"
	if ResourceLoader.exists(powerup_sound_path):
		powerup_sound = load(powerup_sound_path)
		print("加载复活音效成功: %s" % powerup_sound_path)
	else:
		push_warning("音效文件不存在: %s" % powerup_sound_path)
	
	# 设置音效播放器音量（降低50%，约-6dB）
	hit_audio_player.volume_db = -6.0  # -6dB ≈ 50%音量
	broken_audio_player.volume_db = -6.0
	powerup_audio_player.volume_db = -6.0
	
	print("音效系统初始化完成！")

func play_random_hit_sound():
	# 播放随机的点击音效
	if hit_sounds.size() > 0 and hit_audio_player:
		var random_index = randi() % hit_sounds.size()
		var selected_sound = hit_sounds[random_index]
		hit_audio_player.stream = selected_sound
		hit_audio_player.play()
		print("播放点击音效: hitHurt%d" % (random_index + 1))

func play_broken_sound():
	# 播放部位掉落音效
	if broken_sound and broken_audio_player:
		broken_audio_player.stream = broken_sound
		broken_audio_player.play()
		print("播放部位掉落音效: hitbroken")

func play_powerup_sound():
	# 播放复活音效
	if powerup_sound and powerup_audio_player:
		powerup_audio_player.stream = powerup_sound
		powerup_audio_player.play()
		print("播放复活音效: powerUp")

func setup_collision():
	# 碰撞形状已在场景中设置，这里只需要确保节点正确连接
	if collision_shape == null:
		push_error("CollisionShape2D节点引用失败")
		return
	
	# 如果需要动态调整碰撞区域大小，可以在这里修改
	# collision_shape.shape.size = Vector2(192, 128)

func _on_crab_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		# 将全局坐标转换为本地坐标
		var local_click_pos = event.position - crab_container.global_position
		
		# 检查是否点击在非透明像素上
		if is_click_on_crab_sprite(local_click_pos):
			if event.button_index == MOUSE_BUTTON_LEFT:
				print("Area2D确认左键点击在螃蟹非透明像素上")
				handle_crab_click(local_click_pos)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				print("Area2D确认右键点击在螃蟹非透明像素上")
				handle_crab_reset()
		else:
			print("Area2D检测到点击在透明区域")

func handle_crab_click(click_position: Vector2):
	# 增加点击计数
	click_count += 1
	print("螃蟹被点击！点击次数: %d, 点击位置: %s" % [click_count, click_position])
	
	# 播放随机点击音效
	play_random_hit_sound()
	
	# 显示点击表情
	show_click_expression()
	
	# 震动效果
	create_shake_effect()
	
	# 生成碎片特效
	create_debris_effect(click_position)
	
	# 更新螃蟹状态
	update_crab_state()
	
	# 检查部位掉落
	check_part_drops()
	
	# 更新视觉效果
	update_crab_visuals()
	
	# 更新调试信息
	update_debug_info()

func show_click_expression():
	# 如果螃蟹已经死亡，就不显示点击表情了
	if current_crab_state == CrabState.DEAD:
		print("螃蟹已死亡，不显示点击表情")
		return
	
	# 设置为被点击表情
	is_showing_click_expression = true
	update_eye_texture()
	
	# 0.2秒后恢复正常表情
	await get_tree().create_timer(0.2).timeout
	is_showing_click_expression = false
	update_eye_texture()

func create_shake_effect():
	# 拖拽时不执行震动，避免位置冲突
	if is_dragging:
		print("拖拽中，跳过震动效果")
		return
	
	# 创建震动动画
	var tween = create_tween()
	var original_pos = crab_container.position
	
	# 震动效果
	tween.tween_method(shake_crab, 0.0, 1.0, 0.3)
	tween.tween_callback(func(): crab_container.position = original_pos)

func shake_crab(progress: float):
	# 拖拽时不执行震动位置修改，避免冲突
	if is_dragging:
		return
	
	# 随机震动偏移
	var shake_strength = 3.0 * (1.0 - progress)  # 震动强度随时间减弱
	var offset = Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)
	crab_container.position = Vector2.ZERO + offset

func create_debris_effect(click_pos: Vector2):
	# 创建碎片特效
	var debris_count = randi_range(3, 8)
	
	for i in debris_count:
		create_single_debris(click_pos)

func create_single_debris(origin_pos: Vector2):
	# 创建单个碎片
	var debris = Sprite2D.new()
	particle_container.add_child(debris)
	
	# 设置碎片位置
	debris.position = origin_pos
	
	# 尝试加载碎片贴图，如果没有则创建简单的矩形
	if ResourceLoader.exists("res://textures/debris.png"):
		debris.texture = load("res://textures/debris.png")
	else:
		# 创建简单的彩色矩形作为碎片
		var rect_texture = ImageTexture.new()
		var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		var colors = [Color.ORANGE, Color.CORAL, Color.DARK_ORANGE, Color.SANDY_BROWN]
		image.fill(colors[randi() % colors.size()])
		rect_texture.set_image(image)
		debris.texture = rect_texture
	
	# 设置碎片大小
	debris.scale = Vector2(0.5, 0.5)
	
	# 随机飞行方向和速度
	var direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var speed = randf_range(50, 150)
	var gravity = 200
	
	# 动画碎片
	animate_debris(debris, direction, speed, gravity)

func animate_debris(debris: Sprite2D, direction: Vector2, speed: float, gravity: float):
	var tween = create_tween()
	var lifetime = randf_range(0.5, 1.5)
	
	# 并行动画
	tween.parallel().tween_method(
		func(progress): move_debris(debris, direction, speed, gravity, progress),
		0.0, 1.0, lifetime
	)
	
	# 淡出效果
	tween.parallel().tween_property(debris, "modulate:a", 0.0, lifetime)
	
	# 动画结束后删除碎片
	tween.tween_callback(func(): debris.queue_free())

func move_debris(debris: Sprite2D, direction: Vector2, speed: float, gravity: float, progress: float):
	if not is_instance_valid(debris):
		return
		
	var time = progress * 1.5  # 假设最大生命周期为1.5秒
	var pos = debris.position
	
	# 水平移动
	pos.x += direction.x * speed * get_process_delta_time()
	
	# 垂直移动（受重力影响）
	pos.y += (direction.y * speed + gravity * time) * get_process_delta_time()
	
	debris.position = pos

func update_crab_state():
	# 根据点击次数更新螃蟹状态
	var new_state = CrabState.HEALTHY
	
	if click_count >= state_thresholds[CrabState.DEAD]:
		new_state = CrabState.DEAD
	elif click_count >= state_thresholds[CrabState.DYING]:
		new_state = CrabState.DYING
	elif click_count >= state_thresholds[CrabState.DAMAGED]:
		new_state = CrabState.DAMAGED
	elif click_count >= state_thresholds[CrabState.CRACKED]:
		new_state = CrabState.CRACKED
	
	if new_state != current_crab_state:
		current_crab_state = new_state
		update_eye_state()

func update_eye_state():
	# 根据螃蟹状态更新眼神
	match current_crab_state:
		CrabState.HEALTHY:
			current_eye_state = EyeState.THREATENING
		CrabState.CRACKED:
			current_eye_state = EyeState.THREATENING
		CrabState.DAMAGED:
			current_eye_state = EyeState.WEAKENING
		CrabState.DYING:
			current_eye_state = EyeState.DYING
		CrabState.DEAD:
			current_eye_state = EyeState.DEAD

func check_part_drops():
	# 检查是否有部位需要掉落
	for part_name in part_drop_thresholds:
		if click_count >= part_drop_thresholds[part_name] and part_name not in dropped_parts:
			drop_part(part_name)
			dropped_parts.append(part_name)

func drop_part(part_name: String):
	# 掉落指定部位
	var part_sprite: Sprite2D
	
	match part_name:
		"LEGF1":  # 前右腿（画面左侧）
			part_sprite = legf1
		"LEGF2":  # 前左腿（画面右侧）
			part_sprite = legf2
		"LEGB1":  # 后右腿（画面左侧）
			part_sprite = legb1
		"LEGB2":  # 后左腿（画面右侧）
			part_sprite = legb2
		"left_claw":   # 左钳子（画面右侧）
			part_sprite = left_claw
		"right_claw":  # 右钳子（画面左侧）
			part_sprite = right_claw
	
	if part_sprite:
		# 播放部位掉落音效
		play_broken_sound()
		animate_part_drop(part_sprite, part_name)

func animate_part_drop(part: Sprite2D, part_name: String = ""):
	# 部位掉落动画 - 抛物线效果
	print("部位开始掉落: %s" % part.name)
	
	# 确保部位在动画开始时是可见的
	part.visible = true
	part.modulate.a = 1.0
	
	# 保存原始位置
	var start_pos = part.position
	
	# 随机的初始抛射参数
	var throw_force_x = randf_range(-50, 50)  # 水平抛射力
	var throw_force_y = randf_range(-80, -40) # 向上抛射力（负数表示向上）
	var gravity = 200  # 重力加速度
	var rotation_speed = randf_range(-5, 5)  # 旋转速度
	var lifetime = 2.0  # 动画总时长
	
	# 使用Tween来实现抛物线动画
	var tween = create_tween()
	tween.set_parallel(true)  # 允许并行动画
	
	# 如果提供了part_name，存储动画引用方便后续单独控制
	if part_name != "":
		part_drop_tweens[part_name] = tween
	
	# 自定义抛物线运动
	tween.tween_method(
		func(progress: float): animate_projectile_motion(part, start_pos, throw_force_x, throw_force_y, gravity, rotation_speed, progress, lifetime),
		0.0, 1.0, lifetime
	)
	
	# 淡出效果（在最后0.5秒开始淡出）
	tween.tween_property(part, "modulate:a", 0.0, 0.5).set_delay(lifetime - 0.5)
	
	# 动画结束后隐藏部位并清理引用
	tween.tween_callback(func(): 
		part.visible = false
		if part_name != "":
			part_drop_tweens.erase(part_name)  # 清理引用
		print("部位掉落完成: %s" % part.name)
	).set_delay(lifetime)

func animate_projectile_motion(part: Sprite2D, start_pos: Vector2, force_x: float, force_y: float, gravity: float, rotation_speed: float, progress: float, total_time: float):
	# 抛物线运动计算
	if not is_instance_valid(part):
		return
	
	var time = progress * total_time
	
	# 计算新位置（抛物线公式）
	var new_x = start_pos.x + force_x * time
	var new_y = start_pos.y + force_y * time + 0.5 * gravity * time * time
	
	part.position = Vector2(new_x, new_y)
	
	# 旋转效果
	part.rotation += rotation_speed * get_process_delta_time()

func update_crab_visuals():
	# 更新螃蟹的视觉效果
	update_body_texture()
	update_eye_texture()
	update_part_visibility()

func update_body_texture():
	# 根据点击次数选择合适的身体贴图（body1.png到body9.png）
	var body_index = 1  # 默认使用body1.png
	
	# 找到对应的身体状态
	for i in range(body_state_thresholds.size() - 1, -1, -1):
		if click_count >= body_state_thresholds[i]:
			body_index = i + 1
			break
	
	# 加载对应的身体贴图
	var texture_path = "res://textures/body%d.png" % body_index
	crab_body.texture = load(texture_path)

func update_eye_texture():
	# 更新眼神贴图
	if is_showing_click_expression:
		crab_eyes.texture = load("res://textures/eyes_clicked.png")
	else:
		match current_eye_state:
			EyeState.THREATENING:
				crab_eyes.texture = load("res://textures/eyes_threatening.png")
			EyeState.WEAKENING:
				crab_eyes.texture = load("res://textures/eyes_weakening.png")
			EyeState.DYING:
				crab_eyes.texture = load("res://textures/eyes_dying.png")
			EyeState.DEAD:
				crab_eyes.texture = load("res://textures/eyes_dead.png")

func update_part_visibility():
	# 更新部位可见性
	# 注意：不要立即隐藏正在播放掉落动画的部位
	# 掉落动画会在完成后自己隐藏部位
	pass

func update_debug_info():
	# 更新调试信息
	debug_label.text = "点击次数: %d | 状态: %s" % [click_count, get_state_name()]

func get_state_name() -> String:
	match current_crab_state:
		CrabState.HEALTHY:
			return "健康"
		CrabState.CRACKED:
			return "裂缝"
		CrabState.DAMAGED:
			return "损坏"
		CrabState.DYING:
			return "垂死"
		CrabState.DEAD:
			return "死亡"
		_:
			return "未知"

func handle_crab_reset():
	print("开始重置螃蟹到健康状态！")
	
	# 播放复活音效
	play_powerup_sound()
	
	# 重置游戏状态
	click_count = 0
	current_crab_state = CrabState.HEALTHY
	current_eye_state = EyeState.THREATENING
	is_showing_click_expression = false
	dropped_parts.clear()
	
	# 恢复所有部位到原始位置和状态
	restore_all_parts()
	
	# 播放juice特效
	play_reset_juice_effects()
	
	# 更新视觉效果
	update_crab_visuals()
	update_debug_info()
	
	# 调试：检查容器的变换属性
	print("重置后容器状态调试:")
	print("  position: %s" % crab_container.position)
	print("  scale: %s" % crab_container.scale)
	print("  rotation: %s" % crab_container.rotation)
	print("  pivot_offset: %s" % crab_container.pivot_offset)
	print("  modulate: %s" % crab_container.modulate)
	
	print("螃蟹重置完成！")

func restore_all_parts():
	# 只停止部位掉落动画，让粒子动画继续播放
	for part_name in part_drop_tweens:
		var tween = part_drop_tweens[part_name]
		if tween and tween.is_valid():
			tween.kill()
			print("停止部位掉落动画: %s" % part_name)
	
	# 清空部位掉落动画引用
	part_drop_tweens.clear()
	
	# 恢复所有部位的位置、偏移、可见性和透明度
	var parts_data = {
		"LEGF1": legf1,
		"LEGF2": legf2,
		"LEGB1": legb1,
		"LEGB2": legb2,
		"left_claw": left_claw,
		"right_claw": right_claw
	}
	
	for part_name in parts_data:
		var sprite = parts_data[part_name]
		if sprite:
			# 恢复位置和偏移
			sprite.position = original_positions[part_name]
			sprite.offset = original_offsets[part_name]
			
			# 恢复可见性和透明度
			sprite.visible = true
			sprite.modulate = Color.WHITE
			sprite.rotation = 0.0
			sprite.scale = Vector2.ONE
			
			print("恢复部位: %s 到位置 %s" % [part_name, original_positions[part_name]])

func play_reset_juice_effects():
	# 拖拽时不播放重置特效，避免冲突
	if is_dragging:
		print("拖拽中，跳过重置特效")
		return
	
	# 创建多层juice特效
	play_flash_effect()
	play_scale_effect()
	play_sweep_effect()

func play_flash_effect():
	# 全白闪光特效
	print("播放全白闪光特效")
	
	var flash_tween = create_tween()
	
	# 瞬间完全变白（使用加色混合模式实现纯白效果）
	crab_container.modulate = Color(10.0, 10.0, 10.0, 1.0)  # 超强白色
	
	# 快速恢复正常
	flash_tween.tween_property(crab_container, "modulate", Color.WHITE, 0.15)

func play_scale_effect():
	# 缩放特效
	print("播放缩放特效")
	
	# 设置缩放中心为螃蟹中心（192/2, 128/2）
	var crab_center = Vector2(96, 64)
	var original_pivot = crab_container.pivot_offset
	crab_container.pivot_offset = crab_center
	
	var scale_tween = create_tween()
	scale_tween.set_parallel(true)
	
	# 快速放大然后回缩，以螃蟹中心为基准
	scale_tween.tween_property(crab_container, "scale", Vector2(1.2, 1.2), 0.1)
	scale_tween.tween_property(crab_container, "scale", Vector2(0.95, 0.95), 0.15).set_delay(0.1)
	scale_tween.tween_property(crab_container, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.25)
	
	# 动画结束后恢复原始pivot_offset，确保不影响点击检测
	scale_tween.tween_callback(func(): 
		crab_container.pivot_offset = original_pivot
		print("缩放特效完成，恢复pivot_offset")
	).set_delay(0.35)

func play_sweep_effect():
	# 从右到左的扫光特效，只作用在螃蟹身上
	print("播放扫光特效")
	
	# 创建扫光特效 - 对每个螃蟹部位分别应用白色闪烁
	var parts_to_sweep = [crab_body, crab_eyes, legf1, legf2, legb1, legb2, left_claw, right_claw]
	
	var sweep_tween = create_tween()
	sweep_tween.set_parallel(true)
	
	# 为每个可见部位添加从右到左的延迟扫光效果
	for i in range(parts_to_sweep.size()):
		var part = parts_to_sweep[i]
		if part and part.visible:
			# 根据部位的X位置计算延迟时间（从右到左）
			var delay_time = (192 - part.position.x) / 192.0 * 0.2  # 0-0.2秒的延迟
			
			# 瞬间变白然后恢复
			sweep_tween.tween_callback(
				func(): part.modulate = Color(3.0, 3.0, 3.0, 1.0)
			).set_delay(delay_time)
			
			sweep_tween.tween_property(part, "modulate", Color.WHITE, 0.1).set_delay(delay_time + 0.05)

# 拖拽功能实现 - 根据教程优化的简洁方法
func start_dragging():
	is_dragging = true
	print("开始右键拖拽桌宠")

func handle_dragging(global_mouse_pos: Vector2i):
	if is_dragging:
		# 使用鼠标全局位置设置窗口位置，偏移螃蟹中心
		# 这样螃蟹中心会跟随鼠标移动
		var new_window_pos = Vector2i(global_mouse_pos.x - 96, global_mouse_pos.y - 64)
		DisplayServer.window_set_position(new_window_pos)
		print("拖拽到位置: 鼠标=%s, 窗口=%s" % [global_mouse_pos, new_window_pos])

func stop_dragging():
	is_dragging = false
	print("右键拖拽结束")

# 右键菜单相关函数
func create_context_menu():
	# 创建右键菜单
	context_menu = PopupMenu.new()
	add_child(context_menu)
	var theme := Theme.new()
	theme.set_font_size("font_size", "PopupMenu", 24)
	context_menu.theme = theme
	# 添加菜单项
	context_menu.add_item("复活螃蟹", 0)
	context_menu.add_separator()
	context_menu.add_item("我打够了", 1)
	
	# 连接菜单项选择信号
	context_menu.id_pressed.connect(_on_context_menu_selected)
	
	# 设置菜单样式
	context_menu.transparent_bg = true
	
	print("右键菜单创建完成")

func show_context_menu(screen_pos: Vector2i):
	if context_menu == null:
		return
	
	# 使用屏幕绝对坐标显示菜单
	# PopupMenu.popup()需要的是屏幕绝对坐标
	var menu_rect = Rect2i(screen_pos, Vector2i(1, 1))
	
	# 显示菜单在指定的屏幕位置
	context_menu.popup(menu_rect)
	is_context_menu_visible = true
	print("显示右键菜单在屏幕位置: %s" % screen_pos)

func hide_context_menu():
	if context_menu != null:
		context_menu.hide()
		is_context_menu_visible = false
		print("隐藏右键菜单，菜单状态重置为: %s" % is_context_menu_visible)
	else:
		is_context_menu_visible = false
		print("菜单为null，强制重置状态为: %s" % is_context_menu_visible)

func _on_context_menu_selected(id: int):
	# 处理菜单项选择
	print("菜单选择ID: %s" % id)
	
	# 立即隐藏菜单，避免状态问题
	hide_context_menu()
	
	match id:
		0:  # 复活螃蟹
			print("用户选择：复活螃蟹")
			# 等待一帧确保菜单完全隐藏
			await get_tree().process_frame
			handle_crab_reset()
		1:  # 退出程序
			print("用户选择：我打够了")
			show_exit_confirmation()
	
	print("菜单处理完成，is_context_menu_visible: %s" % is_context_menu_visible)

func show_exit_confirmation():
	# 简单的退出确认（可以后续扩展为更漂亮的对话框）
	print("退出程序...")
	get_tree().quit() 
