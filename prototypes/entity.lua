local laser_construction_bot = table.deepcopy(data.raw["construction-robot"]["construction-robot"])
laser_construction_bot.name = "laser-construction-robot"
laser_construction_bot.minable.result = "laser-construction-robot"

-- Create laser logistics bot based on logistic robot
local laser_logistic_bot = table.deepcopy(data.raw["logistic-robot"]["logistic-robot"])
laser_logistic_bot.name = "laser-logistic-robot"
laser_logistic_bot.minable.result = "laser-logistic-robot"

-- Create kamikaze version for construction bot
local kamikaze_construction_bot = table.deepcopy(data.raw["combat-robot"]["defender"])
kamikaze_construction_bot.name = "laser-construction-robot-kamikaze"
kamikaze_construction_bot.max_health = 1000
kamikaze_construction_bot.time_to_live = 600
kamikaze_construction_bot.speed = 0.05
kamikaze_construction_bot.follows_player = false
kamikaze_construction_bot.friction = 0.01
kamikaze_construction_bot.range_from_player = 1000
kamikaze_construction_bot.item_to_place = nil

kamikaze_construction_bot.destroy_action = {
  type = "direct",
  action_delivery = {
    type = "instant",
    source_effects = {
      {
        type = "create-entity",
        entity_name = "explosion"
      }
    }
  }
}

kamikaze_construction_bot.idle = table.deepcopy(laser_construction_bot.idle)
kamikaze_construction_bot.in_motion = table.deepcopy(laser_construction_bot.idle)
kamikaze_construction_bot.shadow_idle = table.deepcopy(laser_construction_bot.shadow_idle)
kamikaze_construction_bot.shadow_in_motion = table.deepcopy(laser_construction_bot.shadow_idle)
kamikaze_construction_bot.light = nil
kamikaze_construction_bot.attack_parameters.cooldown = 600
kamikaze_construction_bot.attack_parameters.range = 0

-- Create kamikaze version for logistic bot
local kamikaze_logistic_bot = table.deepcopy(data.raw["combat-robot"]["defender"])
kamikaze_logistic_bot.name = "laser-logistic-robot-kamikaze"
kamikaze_logistic_bot.max_health = 1000
kamikaze_logistic_bot.time_to_live = 600
kamikaze_logistic_bot.speed = 0.05
kamikaze_logistic_bot.follows_player = false
kamikaze_logistic_bot.friction = 0.01
kamikaze_logistic_bot.range_from_player = 1000
kamikaze_logistic_bot.item_to_place = nil

kamikaze_logistic_bot.destroy_action = {
  type = "direct",
  action_delivery = {
    type = "instant",
    source_effects = {
      {
        type = "create-entity",
        entity_name = "explosion"
      }
    }
  }
}

kamikaze_logistic_bot.idle = table.deepcopy(laser_logistic_bot.idle)
kamikaze_logistic_bot.in_motion = table.deepcopy(laser_logistic_bot.idle)
kamikaze_logistic_bot.shadow_idle = table.deepcopy(laser_logistic_bot.shadow_idle)
kamikaze_logistic_bot.shadow_in_motion = table.deepcopy(laser_logistic_bot.shadow_idle)
kamikaze_logistic_bot.light = nil
kamikaze_logistic_bot.attack_parameters.cooldown = 600
kamikaze_logistic_bot.attack_parameters.range = 0

data:extend({ laser_construction_bot, laser_logistic_bot, kamikaze_construction_bot, kamikaze_logistic_bot })

-- Create a custom EMP explosion with blue electric effect (reduced visual intensity)
local emp_explosion = {
  type = "explosion",
  name = "laser-bot-emp-explosion",
  animations = {
    {
      filename = "__base__/graphics/entity/sparks/sparks-01.png",
      priority = "high",
      width = 39,
      height = 34,
      frame_count = 19,
      line_length = 19,
      animation_speed = 0.5,
      shift = {0, 0},
      tint = {r = 0.2, g = 0.5, b = 1.0, a = 0.65},
      scale = 2.6
    }
  },
  light = {intensity = 1.0, size = 20, color = {r = 0.3, g = 0.6, b = 1.0}},
  smoke = "smoke-fast",
  smoke_count = 1,
  smoke_slow_down_factor = 1,
  sound = {
    aggregation = {
      max_count = 1,
      remove = true
    },
    variations = {
      {
        filename = "__base__/sound/fight/electric-beam.ogg",
        volume = 0.7
      }
    }
  }
}

-- Create custom EMP sticker (reduced visual intensity but same stun effect)
local emp_sticker = {
  type = "sticker",
  name = "emp-sticker",
  flags = {"not-on-map"},
  animation = {
    filename = "__base__/graphics/entity/sparks/sparks-01.png",
    priority = "high",
    width = 39,
    height = 34,
    frame_count = 19,
    line_length = 19,
    animation_speed = 0.3,
    shift = {0, 0},
    tint = {r = 0.3, g = 0.7, b = 1.0, a = 0.5},
    scale = 1.4
  },
  duration_in_ticks = 360,
  movement_modifier = 0.05,
  vehicle_speed_modifier = 0.05,
  damage_per_tick = {amount = 0.5, type = "electric"},  -- REDUCED from 3 to 0.5
  spread_fire_entity = nil,
  fire_spread_cooldown = 0,
  fire_spread_radius = 0
}

data:extend({emp_explosion, emp_sticker})