class_name GameState
extends RefCounted

var amounts: Dictionary = {}        # {short_name: float}
var caps: Dictionary = {}           # {short_name: float}  INF = no cap
var buildings_owned: Dictionary = {} # {short_name: int}
var current_day: int = 0
