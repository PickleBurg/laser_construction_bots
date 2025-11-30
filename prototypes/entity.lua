local laser_bot = table.deepcopy(data.raw["construction-robot"]["construction-robot"])
laser_bot.name = "laser-construction-robot"
laser_bot.minable.result = "laser-construction-robot"

-- Add a laser attack
laser_bot.attack_parameters = {
  type = "projectile",
  ammo_category = "laser",
  cooldown = 20,
  range = 15,
  ammo_type = {
    category = "laser",
    action = {
      type = "direct",
      action_delivery = {
        type = "projectile",
        projectile = "laser",
        starting_speed = 0.5
      }
    }
  }
}

data:extend({ laser_bot })
