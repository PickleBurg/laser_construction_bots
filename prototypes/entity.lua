local laser_bot = table.deepcopy(data.raw["construction-robot"]["construction-robot"])
laser_bot.name = "laser-construction-robot"
laser_bot.minable.result = "laser-construction-robot"

-- Create kamikaze version as a simple combat robot (no AI, manually controlled)
local kamikaze_bot = table.deepcopy(data.raw["combat-robot"]["defender"])
kamikaze_bot.name = "laser-construction-robot-kamikaze"
kamikaze_bot.max_health = 1000  -- High health so it doesn't die easily
kamikaze_bot.time_to_live = 600  -- 10 seconds max lifetime
kamikaze_bot.speed = 0.05  -- Increased speed to match construction robot
kamikaze_bot.follows_player = false
kamikaze_bot.friction = 0.01
kamikaze_bot.range_from_player = 1000
kamikaze_bot.item_to_place = nil

-- Add destroy action to show robot death animation
kamikaze_bot.destroy_action = {
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

-- Use construction robot graphics
kamikaze_bot.idle = table.deepcopy(laser_bot.idle)
kamikaze_bot.in_motion = table.deepcopy(laser_bot.idle)
kamikaze_bot.shadow_idle = table.deepcopy(laser_bot.shadow_idle)
kamikaze_bot.shadow_in_motion = table.deepcopy(laser_bot.shadow_idle)

-- Remove red warning light - no light at all for stealth
kamikaze_bot.light = nil

-- Keep the original defender's attack parameters (we'll control explosion manually anyway)
-- Just make it very weak and slow so it doesn't interfere
kamikaze_bot.attack_parameters.cooldown = 600
kamikaze_bot.attack_parameters.range = 0

data:extend({ laser_bot, kamikaze_bot })

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
      tint = {r = 0.2, g = 0.5, b = 1.0, a = 0.65},  -- Reduced alpha from 1.0 to 0.65 (35% reduction)
      scale = 2.6  -- Reduced from 4 to 2.6 (35% reduction)
    }
  },
  light = {intensity = 1.0, size = 20, color = {r = 0.3, g = 0.6, b = 1.0}},  -- Reduced intensity from 1.5 to 1.0, size from 30 to 20
  smoke = "smoke-fast",
  smoke_count = 1,  -- Reduced from 2 to 1 (50% reduction)
  smoke_slow_down_factor = 1,
  sound = {
    aggregation = {
      max_count = 1,
      remove = true
    },
    variations = {
      {
        filename = "__base__/sound/fight/electric-beam.ogg",
        volume = 0.7  -- Reduced volume from 1.0 to 0.7 (30% reduction)
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
    tint = {r = 0.3, g = 0.7, b = 1.0, a = 0.5},  -- Reduced alpha from 0.7 to 0.5 (28% reduction)
    scale = 1.4  -- Reduced from 2.0 to 1.4 (30% reduction)
  },
  duration_in_ticks = 360,  -- 6 seconds stun
  movement_modifier = 0.05,  -- 95% slowdown - almost completely stunned!
  vehicle_speed_modifier = 0.05,  -- Also slow vehicles
  damage_per_tick = {amount = 3, type = "electric"},  -- 3 electric damage per tick (18 DPS over 6 seconds = 108 total damage)
  spread_fire_entity = nil,
  fire_spread_cooldown = 0,
  fire_spread_radius = 0
}

data:extend({emp_explosion, emp_sticker})