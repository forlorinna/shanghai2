extends RefCounted

const JOBS := [
	["taxi", "出租车载客", "Taxi Fare", "bund", "peace", 170, 1],
	["delivery", "城市送货", "City Delivery", "mall", "green", 140, 0],
	["race", "陆家嘴赛车", "Lujiazui Sprint", "century", "jinmao", 300, 78],
	["night", "外滩夜间驾驶", "Bund Night Drive", "bridge", "bund", 220, 95],
	["photo", "城市摄影", "City Photography", "pearl", "pearl", 190, 2],
	["visit", "地标打卡", "Landmark Check-in", "promenade", "convention", 120, 0],
	["ferry", "轮渡体验", "Huangpu Ferry", "wharf", "wharf", 170, 3],
	["timer", "限时驾驶", "Timed Drive", "green", "swfc", 200, 65],
	["random", "随机城市事件", "City Dispatch", "nanjing", "customs", 160, 0],
]
var current: Dictionary = {}
var completed: Array = []
var game

func start(slot: int) -> void:
	if slot < 0 or slot >= JOBS.size():
		return
	var job: Array = JOBS[slot]
	current = {"id":slot, "leg":0, "remaining":float(job[6]), "running":false}
	if job[0] == "night":
		game.climate.hour = 21.0
	if job[0] == "ferry":
		game.set_destination(game.world.ferry_path[0])
	else:
		game.set_destination(game.place(job[3], true))
	game.notice(game.bi("任务已接受 · ", "Job accepted · ") + game.bi(job[1], job[2]))

func job_name() -> String:
	if current.is_empty():
		return ""
	var job: Array = JOBS[int(current.id)]
	return game.bi(job[1], job[2])

func detail() -> String:
	if current.is_empty():
		return ""
	var job: Array = JOBS[int(current.id)]
	if job[0] == "photo":
		return game.bi("接近地标，用手机拍照", "Reach the landmark and take a photo")
	if job[0] == "ferry":
		return game.bi("搭乘轮渡并完成一次过江", "Take the ferry across the Huangpu")
	if job[0] == "taxi" and (game.driving == null or game.driving.variant != 3):
		return game.bi("使用出租车接客", "Pick up the fare in a taxi")
	if current.running:
		return game.bi("计时 ", "Timer ") + "%02d" % ceili(current.remaining)
	return game.bi("前往高亮目的地", "Follow the highlighted route")

func tick(at: Vector3, delta: float) -> void:
	if current.is_empty():
		return
	var job: Array = JOBS[int(current.id)]
	if current.running:
		current.remaining -= delta
		if current.remaining <= 0:
			current.clear()
			game.clear_destination()
			game.notice(game.bi("时间到 · 可在手机中重试", "Time expired · Retry from the phone"))
			return
	if job[0] in ["photo", "ferry"]:
		return
	if job[0] == "taxi" and (game.driving == null or game.driving.variant != 3):
		return
	if int(job[6]) > 3 and game.driving == null:
		return
	var goal: Vector3 = game.place(job[3 if int(current.leg) == 0 else 4], true)
	if Vector2(goal.x - at.x, goal.z - at.z).length() > 17.0:
		return
	if int(current.leg) == 0:
		current.leg = 1
		current.running = int(job[6]) > 3
		game.set_destination(game.place(job[4], true))
		game.notice(game.bi("已到达 · 前往下一站", "Checkpoint · Proceed to the destination"))
	else:
		finish()

func event(kind: String, at: Vector3) -> void:
	if current.is_empty():
		return
	var job: Array = JOBS[int(current.id)]
	if job[0] == kind and (kind == "ferry" or at.distance_to(game.place(job[3], false)) < 180.0):
		finish()

func finish() -> void:
	var job: Array = JOBS[int(current.id)]
	current.clear()
	if not completed.has(job[0]):
		completed.append(job[0])
	game.money += int(job[5])
	game.clear_destination()
	game.feedback("complete", game.focus())
	game.notice(game.bi("任务完成", "Job complete") + "   +¥%s" % job[5])
	game.save_game(false)
