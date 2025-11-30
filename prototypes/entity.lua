local laser_bot = table.deepcopy(data.raw["construction-robot"]["construction-robot"])
laser_bot.name = "laser-construction-robot"
laser_bot.minable.result = "laser-construction-robot"

data:extend({ laser_bot })
