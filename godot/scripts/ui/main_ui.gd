extends Control

func _ready() -> void:
	_connect_nav_buttons()
	_connect_speed_buttons()
	_connect_program_slots()


func _connect_nav_buttons() -> void:
	var nav_vbox := $MainVBox/ContentHBox/LeftSidebar/SidebarScroll/NavVBox
	for btn_name: String in [
		"BtnCommands", "BtnBuildings", "BtnResearch", "BtnProjects",
		"BtnIdeologies", "BtnAdversaries", "BtnStats", "BtnAchievements",
		"BtnOptions", "BtnExit",
	]:
		var btn: Button = nav_vbox.get_node(btn_name)
		btn.pressed.connect(func(): print(btn.text))


func _connect_speed_buttons() -> void:
	var speed_row := $MainVBox/ContentHBox/LeftSidebar/SidebarScroll/NavVBox/SpeedRow
	for btn: Button in speed_row.get_children():
		btn.pressed.connect(func(): print("Speed: " + btn.text))


func _connect_program_slots() -> void:
	var slots := $MainVBox/ContentHBox/RightPanel/RightVBox/ProgramSlots
	for btn: Button in slots.get_children():
		btn.pressed.connect(func(): print("Program slot: " + btn.text))
