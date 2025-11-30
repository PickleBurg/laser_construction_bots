-- Detect if Space Age DLC is installed
local has_space_age_dlc = data.raw.tool["metallurgic-science-pack"] ~= nil

-- Base technology - requires production science, moderately expensive
data:extend({
  {
    type = "technology",
    name = "laser-construction-bots",
    icon = "__base__/graphics/technology/construction-robotics.png",
    icon_size = 256,
    prerequisites = {"construction-robotics", "laser", "production-science-pack"},
    effects = {
      {
        type = "unlock-recipe",
        recipe = "laser-construction-robot"
      }
    },
    unit = {
      count = 500,  -- Expensive but achievable in mid-game
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1}
      },
      time = 45
    },
    localised_name = {"", "Laser Construction Bots"},
    localised_description = {"", "Construction robots equipped with laser weapons. They automatically attack nearby enemies while building."}
  }
})

-- DAMAGE UPGRADE PATH (10 levels: 10 damage -> 50 damage)
-- Levels 1-3: Early game (5 vanilla packs)
for level = 1, 3 do
  local damage_value = 10 + (level * 4)
  data:extend({
    {
      type = "technology",
      name = "laser-construction-bots-damage-" .. tostring(level),
      icon = "__base__/graphics/technology/laser-turret.png",
      icon_size = 256,
      prerequisites = level == 1 and {"laser-construction-bots"} or {"laser-construction-bots-damage-" .. tostring(level - 1)},
      effects = {
        {
          type = "nothing",
          effect_description = {"", "Laser damage: ", tostring(damage_value)}
        }
      },
      unit = {
        count = 300 * level,  -- 300, 600, 900
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"military-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1}
        },
        time = 45
      },
      upgrade = true,
      order = "c-k-f-a-" .. tostring(level),
      localised_name = {"", "Laser Construction Bots Damage ", tostring(level)},
      localised_description = {"", "Increases laser damage to ", tostring(damage_value), " per shot."}
    }
  })
end

-- Levels 4-5: Mid-late game (add utility)
for level = 4, 5 do
  local damage_value = 10 + (level * 4)
  data:extend({
    {
      type = "technology",
      name = "laser-construction-bots-damage-" .. tostring(level),
      icon = "__base__/graphics/technology/laser-turret.png",
      icon_size = 256,
      prerequisites = {"laser-construction-bots-damage-" .. tostring(level - 1)},
      effects = {
        {
          type = "nothing",
          effect_description = {"", "Laser damage: ", tostring(damage_value)}
        }
      },
      unit = {
        count = 400 * level,  -- 1600, 2000
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"military-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1},
          {"utility-science-pack", 1}
        },
        time = 60
      },
      upgrade = true,
      order = "c-k-f-a-" .. tostring(level),
      localised_name = {"", "Laser Construction Bots Damage ", tostring(level)},
      localised_description = {"", "Increases laser damage to ", tostring(damage_value), " per shot."}
    }
  })
end

-- Levels 6-7: Late game (add space science)
for level = 6, 7 do
  local damage_value = 10 + (level * 4)
  data:extend({
    {
      type = "technology",
      name = "laser-construction-bots-damage-" .. tostring(level),
      icon = "__base__/graphics/technology/laser-turret.png",
      icon_size = 256,
      prerequisites = {"laser-construction-bots-damage-" .. tostring(level - 1), "space-science-pack"},
      effects = {
        {
          type = "nothing",
          effect_description = {"", "Laser damage: ", tostring(damage_value)}
        }
      },
      unit = {
        count = 500 * level,  -- 3000, 3500
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"military-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1},
          {"utility-science-pack", 1},
          {"space-science-pack", 1}
        },
        time = 60
      },
      upgrade = true,
      order = "c-k-f-a-" .. tostring(level),
      localised_name = {"", "Laser Construction Bots Damage ", tostring(level)},
      localised_description = {"", "Increases laser damage to ", tostring(damage_value), " per shot."}
    }
  })
end

-- Levels 8-10: End game (conditionally add DLC sciences)
for level = 8, 10 do
  local damage_value = 10 + (level * 4)
  local ingredients = {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"military-science-pack", 1},
    {"chemical-science-pack", 1},
    {"production-science-pack", 1},
    {"utility-science-pack", 1},
    {"space-science-pack", 1}
  }
  
  -- Add DLC science packs progressively if DLC is installed
  if has_space_age_dlc then
    if level >= 8 then
      table.insert(ingredients, {"metallurgic-science-pack", 1})
    end
    if level >= 9 then
      table.insert(ingredients, {"agricultural-science-pack", 1})
      table.insert(ingredients, {"electromagnetic-science-pack", 1})
    end
    if level >= 10 then
      table.insert(ingredients, {"cryogenic-science-pack", 1})
    end
  end
  
  data:extend({
    {
      type = "technology",
      name = "laser-construction-bots-damage-" .. tostring(level),
      icon = "__base__/graphics/technology/laser-turret.png",
      icon_size = 256,
      prerequisites = {"laser-construction-bots-damage-" .. tostring(level - 1)},
      effects = {
        {
          type = "nothing",
          effect_description = {"", "Laser damage: ", tostring(damage_value)}
        }
      },
      unit = {
        count = 600 * level,  -- 4800, 5400, 6000
        ingredients = ingredients,
        time = 60
      },
      upgrade = true,
      order = "c-k-f-a-" .. tostring(level),
      localised_name = {"", "Laser Construction Bots Damage ", tostring(level)},
      localised_description = {"", "Increases laser damage to ", tostring(damage_value), " per shot."}
    }
  })
end

-- COOLDOWN UPGRADE PATH (10 levels: 300 ticks -> 0 ticks)
-- Levels 1-3: Early game (5 vanilla packs)
for level = 1, 3 do
  local cooldown_reduction = level * 30
  local cooldown_value = 300 - cooldown_reduction
  local seconds = cooldown_value / 60
  data:extend({
    {
      type = "technology",
      name = "laser-construction-bots-cooldown-" .. tostring(level),
      icon = "__base__/graphics/technology/laser-shooting-speed.png",
      icon_size = 256,
      prerequisites = level == 1 and {"laser-construction-bots"} or {"laser-construction-bots-cooldown-" .. tostring(level - 1)},
      effects = {
        {
          type = "nothing",
          effect_description = {"", "Fire cooldown: ", tostring(cooldown_value), " ticks"}
        }
      },
      unit = {
        count = 300 * level,  -- 300, 600, 900
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"military-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1}
        },
        time = 45
      },
      upgrade = true,
      order = "c-k-f-b-" .. tostring(level),
      localised_name = {"", "Laser Construction Bots Fire Rate ", tostring(level)},
      localised_description = {"", "Reduces fire cooldown to ", tostring(cooldown_value), " ticks (", tostring(seconds), " seconds)."}
    }
  })
end

-- Levels 4-5: Mid-late game (add utility)
for level = 4, 5 do
  local cooldown_reduction = level * 30
  local cooldown_value = 300 - cooldown_reduction
  local seconds = cooldown_value / 60
  data:extend({
    {
      type = "technology",
      name = "laser-construction-bots-cooldown-" .. tostring(level),
      icon = "__base__/graphics/technology/laser-shooting-speed.png",
      icon_size = 256,
      prerequisites = {"laser-construction-bots-cooldown-" .. tostring(level - 1)},
      effects = {
        {
          type = "nothing",
          effect_description = {"", "Fire cooldown: ", tostring(cooldown_value), " ticks"}
        }
      },
      unit = {
        count = 400 * level,  -- 1600, 2000
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"military-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1},
          {"utility-science-pack", 1}
        },
        time = 60
      },
      upgrade = true,
      order = "c-k-f-b-" .. tostring(level),
      localised_name = {"", "Laser Construction Bots Fire Rate ", tostring(level)},
      localised_description = {"", "Reduces fire cooldown to ", tostring(cooldown_value), " ticks (", tostring(seconds), " seconds)."}
    }
  })
end

-- Levels 6-7: Late game (add space science)
for level = 6, 7 do
  local cooldown_reduction = level * 30
  local cooldown_value = 300 - cooldown_reduction
  local seconds = cooldown_value / 60
  data:extend({
    {
      type = "technology",
      name = "laser-construction-bots-cooldown-" .. tostring(level),
      icon = "__base__/graphics/technology/laser-shooting-speed.png",
      icon_size = 256,
      prerequisites = {"laser-construction-bots-cooldown-" .. tostring(level - 1), "space-science-pack"},
      effects = {
        {
          type = "nothing",
          effect_description = {"", "Fire cooldown: ", tostring(cooldown_value), " ticks"}
        }
      },
      unit = {
        count = 500 * level,  -- 3000, 3500
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
          {"military-science-pack", 1},
          {"chemical-science-pack", 1},
          {"production-science-pack", 1},
          {"utility-science-pack", 1},
          {"space-science-pack", 1}
        },
        time = 60
      },
      upgrade = true,
      order = "c-k-f-b-" .. tostring(level),
      localised_name = {"", "Laser Construction Bots Fire Rate ", tostring(level)},
      localised_description = {"", "Reduces fire cooldown to ", tostring(cooldown_value), " ticks (", tostring(seconds), " seconds)."}
    }
  })
end

-- Levels 8-10: End game (conditionally add DLC sciences)
for level = 8, 10 do
  local cooldown_reduction = level * 30
  local cooldown_value = 300 - cooldown_reduction
  local seconds = cooldown_value / 60
  local ingredients = {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"military-science-pack", 1},
    {"chemical-science-pack", 1},
    {"production-science-pack", 1},
    {"utility-science-pack", 1},
    {"space-science-pack", 1}
  }
  
  -- Add DLC science packs progressively if DLC is installed
  if has_space_age_dlc then
    if level >= 8 then
      table.insert(ingredients, {"metallurgic-science-pack", 1})
    end
    if level >= 9 then
      table.insert(ingredients, {"agricultural-science-pack", 1})
      table.insert(ingredients, {"electromagnetic-science-pack", 1})
    end
    if level >= 10 then
      table.insert(ingredients, {"cryogenic-science-pack", 1})
    end
  end
  
  local description
  if cooldown_value == 0 then
    description = {"", "Removes fire cooldown completely (instant firing)."}
  else
    description = {"", "Reduces fire cooldown to ", tostring(cooldown_value), " ticks (", tostring(seconds), " seconds)."}
  end
  
  data:extend({
    {
      type = "technology",
      name = "laser-construction-bots-cooldown-" .. tostring(level),
      icon = "__base__/graphics/technology/laser-shooting-speed.png",
      icon_size = 256,
      prerequisites = {"laser-construction-bots-cooldown-" .. tostring(level - 1)},
      effects = {
        {
          type = "nothing",
          effect_description = {"", "Fire cooldown: ", tostring(cooldown_value), " ticks"}
        }
      },
      unit = {
        count = 600 * level,  -- 4800, 5400, 6000
        ingredients = ingredients,
        time = 60
      },
      upgrade = true,
      order = "c-k-f-b-" .. tostring(level),
      localised_name = {"", "Laser Construction Bots Fire Rate ", tostring(level)},
      localised_description = description
    }
  })
end
