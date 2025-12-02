-- Track firing state for normal bots
local bot_fire_state = {}

-- Track bots that are transitioning to kamikaze (prevent multiple triggers)
local bots_going_kamikaze = {}

-- Track kamikaze bots and their targets for manual movement
local kamikaze_bots = {}

-- Track last enemy contact time for each bot
local bot_last_enemy_contact = {}

-- Performance optimization: Cache research values per force
local force_damage_cache = {}
local force_cooldown_cache = {}
local cache_tick = {}

-- Performance optimization: Track laser bots only
local laser_bots = {}  -- Set of laser bot unit_numbers for quick lookup

-- Performance optimization: Chunk processing
local bot_processing_chunks = {}
local current_chunk = 1
local BOTS_PER_CHUNK = 100  -- Process 100 bots per tick
local CHUNK_COUNT = 10  -- Spread across 10 ticks

-- Function to get vanilla laser damage bonus (from energy-weapons-damage research) - CACHED
local function get_vanilla_laser_damage_bonus(force, current_tick)
  local force_name = force.name
  
  -- Return cached value if less than 5 seconds old (300 ticks)
  if cache_tick[force_name] and (current_tick - cache_tick[force_name]) < 300 then
    if force_damage_cache[force_name] then
      return force_damage_cache[force_name]
    end
  end
  
  -- Recalculate
  local bonus = 1.0
  for i = 1, 1000 do
    local tech_name = "energy-weapons-damage-" .. i
    if force.technologies[tech_name] and force.technologies[tech_name].researched then
      bonus = bonus + 0.1
    else
      break
    end
  end
  
  -- Update cache
  force_damage_cache[force_name] = bonus
  cache_tick[force_name] = current_tick
  
  return bonus
end

-- Function to calculate laser damage based on vanilla research - CACHED
local function get_laser_damage(force, current_tick)
  local base_damage = 5
  local bonus_multiplier = get_vanilla_laser_damage_bonus(force, current_tick)
  return base_damage * bonus_multiplier
end

-- Function to get current cooldown upgrade level - CACHED
local function get_cooldown_level(force, current_tick)
  local force_name = force.name
  
  -- Return cached value if less than 5 seconds old
  if cache_tick[force_name] and (current_tick - cache_tick[force_name]) < 300 then
    if force_cooldown_cache[force_name] then
      return force_cooldown_cache[force_name]
    end
  end
  
  -- Recalculate
  for level = 10, 1, -1 do
    if force.technologies["laser-construction-bots-cooldown-" .. level] and 
       force.technologies["laser-construction-bots-cooldown-" .. level].researched then
      force_cooldown_cache[force_name] = level
      return level
    end
  end
  
  force_cooldown_cache[force_name] = 0
  return 0
end

-- Function to calculate cooldown based on upgrade level
local function get_laser_cooldown(force, current_tick)
  local level = get_cooldown_level(force, current_tick)
  return math.max(0, 300 - (level * 30))
end

-- Clear cache when research finishes
script.on_event(defines.events.on_research_finished, function(event)
  local force_name = event.research.force.name
  force_damage_cache[force_name] = nil
  force_cooldown_cache[force_name] = nil
  cache_tick[force_name] = nil
end)

-- Track when laser bots are built
local function register_laser_bot(entity)
  if entity and entity.valid then
    if entity.name == "laser-construction-robot" or entity.name == "laser-logistic-robot" then
      laser_bots[entity.unit_number] = entity
    end
  end
end

script.on_event(defines.events.on_built_entity, function(event)
  register_laser_bot(event.created_entity or event.entity)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
  register_laser_bot(event.created_entity)
end)

-- Rebuild chunks periodically (every 60 ticks = 1 second)
script.on_nth_tick(60, function(event)
  -- Rebuild chunks from laser_bots
  bot_processing_chunks = {}
  for i = 1, CHUNK_COUNT do
    bot_processing_chunks[i] = {}
  end
  
  local chunk_index = 1
  for bot_id, bot in pairs(laser_bots) do
    -- Clean up invalid bots during rebuild
    if not (bot and bot.valid) then
      laser_bots[bot_id] = nil
      bot_fire_state[bot_id] = nil
      bot_last_enemy_contact[bot_id] = nil
    else
      table.insert(bot_processing_chunks[chunk_index], {id = bot_id, bot = bot})
      chunk_index = chunk_index + 1
      if chunk_index > CHUNK_COUNT then
        chunk_index = 1
      end
    end
  end
end)

-- Process one chunk per tick (spread load across 10 ticks)
script.on_nth_tick(1, function(event)
  local current_tick = event.tick
  
  -- First, handle kamikaze bots movement (every tick for smooth movement)
  for kamikaze, data in pairs(kamikaze_bots) do
    if not (kamikaze and kamikaze.valid) then
      kamikaze_bots[kamikaze] = nil
      goto continue_kamikaze
    end
    
    -- Make kamikaze invulnerable
    if kamikaze.destructible then
      kamikaze.destructible = false
    end
    
    -- Check if kamikaze bot has timed out (after creation time)
    if not data.created_tick then
      data.created_tick = current_tick
    end
    
    local time_alive = current_tick - data.created_tick
    local has_timed_out = time_alive > 200
    
    local target = data.target
    local target_pos = data.target_pos
    
    -- Update target position if target still exists
    if target and target.valid then
      target_pos = target.position
      data.target_pos = {x = target_pos.x, y = target_pos.y}
    end
    
    -- Calculate distance to target
    local dx = target_pos.x - kamikaze.position.x
    local dy = target_pos.y - kamikaze.position.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- Create white steam-like smoke (very infrequently and small)
    if current_tick % 15 == 0 then
      kamikaze.surface.create_trivial_smoke{
        name = "light-smoke",
        position = kamikaze.position
      }
    end
    
    if current_tick % 3 == 0 then
      kamikaze.surface.create_entity{
        name = "flying-robot-damaged-explosion",
        position = kamikaze.position
      }
    end
    
    -- EXPLODE when close enough to target (2 tiles) OR timed out
    if dist < 2.0 or has_timed_out then
      -- Play crash animation - robot exploding
      local explosion_name = data.bot_type == "logistic" and "logistic-robot-explosion" or "construction-robot-explosion"
      kamikaze.surface.create_entity{
        name = explosion_name,
        position = kamikaze.position
      }
      
      -- Small delay visual - sparks burst (reduced from 5 to 3)
      for i = 1, 3 do
        local offset_x = (math.random() - 0.5) * 1.5
        local offset_y = (math.random() - 0.5) * 1.5
        kamikaze.surface.create_entity{
          name = "flying-robot-damaged-explosion",
          position = {x = kamikaze.position.x + offset_x, y = kamikaze.position.y + offset_y}
        }
      end
      
      -- Create fire effect at explosion point
      kamikaze.surface.create_entity{
        name = "fire-flame-on-tree",
        position = kamikaze.position
      }
      
      -- Manually trigger the EMP explosion effects
      kamikaze.surface.create_entity{
        name = "laser-bot-emp-explosion",
        position = kamikaze.position
      }
      
      -- Apply EMP effects to all enemies in range (NOT players)
      local entities_in_range = kamikaze.surface.find_entities_filtered{
        position = kamikaze.position,
        radius = 12,
        force = "enemy"  -- Only search enemy force
      }
      
      for _, entity in pairs(entities_in_range) do
        -- Check entity validity FIRST before accessing any properties
        if not entity.valid then
          goto skip_entity
        end
        
        -- Skip characters
        if entity.type == "character" then
          goto skip_entity
        end
        
        -- Apply minimal damage (5 electric damage) - WORKS ON ALL ENEMIES
        if entity.health then
          entity.damage(5, kamikaze.force, "electric")  -- REDUCED from 5 to 1
          
          -- Check if entity is still valid after damage (might have been destroyed)
          if not entity.valid then
            goto skip_entity
          end
          
          -- Apply EMP sticker for visual effect and STRONG slowdown (ONLY IF ENTITY CAN ACCEPT STICKERS)
          if entity.prototype and entity.prototype.sticker_box then
            pcall(function()
              if entity.valid then
                entity.surface.create_entity{
                  name = "emp-sticker",
                  position = entity.position,
                  target = entity
                }
              end
            end)
          end
          
          -- Create electric sparks on each affected enemy - WORKS ON ALL ENEMIES
          if entity.valid then
            entity.surface.create_entity{
              name = "flying-robot-damaged-explosion",
              position = entity.position
            }
          end
        end
        
        ::skip_entity::
      end
      
      -- Clean up and destroy kamikaze
      kamikaze_bots[kamikaze] = nil
      kamikaze.destroy()
    else
      -- Move kamikaze toward target using teleport (EVERY TICK for smooth movement)
      local base_speed = 0.05
      local move_speed = base_speed
      
      local move_x = (dx / dist) * move_speed
      local move_y = (dy / dist) * move_speed
      kamikaze.teleport{x = kamikaze.position.x + move_x, y = kamikaze.position.y + move_y}
    end
    
    ::continue_kamikaze::
  end
  
  -- Then, handle laser bot processing (chunked)
  -- Rotate through chunks
  current_chunk = (current_tick % CHUNK_COUNT) + 1
  
  local chunk = bot_processing_chunks[current_chunk]
  if not chunk then return end
  
  -- Cache research values once per chunk
  local cached_damages = {}
  local cached_cooldowns = {}
  
  for _, bot_data in ipairs(chunk) do
    local bot = bot_data.bot
    local bot_id = bot_data.id
    
    -- Validate bot
    if not (bot and bot.valid) then
      goto continue
    end
    
    -- Skip bots going kamikaze
    if bots_going_kamikaze[bot_id] then
      goto continue
    end

    -- Initialize bot state if new
    if not bot_fire_state[bot_id] then
      bot_fire_state[bot_id] = {
        fire_time = 0,
        cooldown_until = 0,
        in_roboport = false,
        random_cooldown = math.random(60, 180)
      }
    end

    local state = bot_fire_state[bot_id]
    
    -- Skip bots in roboports to save performance
    local currently_in_roboport = bot.logistic_cell ~= nil and bot.to_be_looted == false
    if currently_in_roboport then
      state.in_roboport = true
      goto continue
    end
    
    -- Skip if on cooldown
    if current_tick < state.cooldown_until then
      goto continue
    end
    
    -- Get cached research bonuses (cache per force for this chunk)
    local force_name = bot.force.name
    if not cached_damages[force_name] then
      cached_damages[force_name] = get_laser_damage(bot.force, current_tick)
      cached_cooldowns[force_name] = get_laser_cooldown(bot.force, current_tick)
    end
    
    local laser_damage = cached_damages[force_name]
    local laser_cooldown = cached_cooldowns[force_name]
    
    -- Normal laser firing logic (optimized enemy search)
    local enemies = bot.surface.find_entities_filtered{
      position = bot.position,
      radius = 15,
      force = "enemy",
      limit = 1
    }

    if enemies[1] and enemies[1].valid and enemies[1].health and bot.energy > 1000 then
      local target = enemies[1]

      -- Update last enemy contact time
      bot_last_enemy_contact[bot_id] = current_tick

      if state.in_roboport then
        state.cooldown_until = 0
        state.fire_time = 0
      end

      state.in_roboport = false

      if state.fire_time >= 120 then
        -- After firing for 2 seconds, cooldown based on research with random offset
        state.cooldown_until = current_tick + laser_cooldown + math.random(-30, 30)
        state.fire_time = 0
      else
        bot.surface.create_entity{
          name = "laser-beam",
          position = bot.position,
          target = target,
          source = bot,
          duration = 10
        }

        -- Apply researched damage
        target.damage(laser_damage, bot.force, "laser", bot)
        bot.energy = bot.energy - 1000
        state.fire_time = state.fire_time + 10
      end
    else
      -- No enemy in range - check if we should reset cooldown
      if bot_last_enemy_contact[bot_id] then
        local time_since_enemy = current_tick - bot_last_enemy_contact[bot_id]
        
        if time_since_enemy >= 120 then
          state.cooldown_until = current_tick + state.random_cooldown
          state.random_cooldown = math.random(60, 180)
          bot_last_enemy_contact[bot_id] = nil
        end
      end
    end
    
    ::continue::
  end
end)

-- Helper function to handle kamikaze transformation
local function transform_to_kamikaze(bot, event)
  local bot_id = bot.unit_number
  
  -- Prevent multiple kamikaze triggers for the same bot
  if bots_going_kamikaze[bot_id] then return end
  
  -- Check if health is below 10
  if bot.health <= 10 then
    -- Mark this bot as transitioning to kamikaze
    bots_going_kamikaze[bot_id] = true
    
    -- Determine bot type
    local bot_type = bot.type == "logistic-robot" and "logistic" or "construction"
    local kamikaze_name = bot_type == "logistic" and "laser-logistic-robot-kamikaze" or "laser-construction-robot-kamikaze"
    
    -- Store bot info before it's destroyed
    local bot_position = {x = bot.position.x, y = bot.position.y}
    local bot_surface = bot.surface
    local bot_force = bot.force
    
    -- Find enemies, prioritize biters/worms over spawners (min 2 tiles, max 15 tiles)
    local enemies = bot_surface.find_entities_filtered{
      position = bot_position,
      radius = 15,
      force = "enemy"
    }
    
    -- Separate enemies by priority: units (biters/spitters), turrets (worms), then spawners
    local priority_targets = {}
    local low_priority_targets = {}
    
    for _, enemy in pairs(enemies) do
      -- Skip players/characters - NEVER target players
      if enemy.type == "character" then
        goto skip_enemy
      end
      
      local dx = enemy.position.x - bot_position.x
      local dy = enemy.position.y - bot_position.y
      local distance = math.sqrt(dx*dx + dy*dy)
      
      -- Only consider enemies at least 2 tiles away
      if distance >= 2 then
        local enemy_data = {entity = enemy, distance = distance}
        
        -- Priority: biters/spitters (unit) and worms (turret)
        if enemy.type == "unit" or enemy.type == "turret" then
          table.insert(priority_targets, enemy_data)
        -- Low priority: spawner nests
        elseif enemy.type == "unit-spawner" then
          table.insert(low_priority_targets, enemy_data)
        else
          -- Any other enemy type goes to priority list
          table.insert(priority_targets, enemy_data)
        end
      end
      
      ::skip_enemy::
    end
    
    -- Sort both lists by distance (FARTHEST first)
    table.sort(priority_targets, function(a, b) return a.distance > b.distance end)
    table.sort(low_priority_targets, function(a, b) return a.distance > b.distance end)
    
    -- Pick target: prioritize biters/worms, fallback to spawners
    local target
    if #priority_targets > 0 then
      target = priority_targets[1].entity
    elseif #low_priority_targets > 0 then
      target = low_priority_targets[1].entity
    end
    
    -- Clean up normal bot FIRST
    bot_fire_state[bot_id] = nil
    bot_last_enemy_contact[bot_id] = nil
    laser_bots[bot_id] = nil  -- Remove from tracking
    bot.destroy()
    
    -- Then create kamikaze unit
    if target and target.valid then
      local kamikaze = bot_surface.create_entity{
        name = kamikaze_name,
        position = bot_position,
        force = bot_force
      }
      
      if kamikaze then
        -- Make kamikaze invulnerable immediately
        kamikaze.destructible = false
        
        -- Track kamikaze bot for manual movement control
        kamikaze_bots[kamikaze] = {
          target = target,
          target_pos = {x = target.position.x, y = target.position.y},
          created_tick = event.tick,
          bot_type = bot_type
        }
        
        -- Create initial warning effects
        bot_surface.create_entity{
          name = "flying-robot-damaged-explosion",
          position = bot_position
        }
      end
    else
      -- Target too close (< 2 tiles), move to a random point between 3-15 tiles away
      local angle = math.random() * 2 * math.pi
      local random_distance = 3 + math.random() * 12
      local random_pos = {
        x = bot_position.x + math.cos(angle) * random_distance,
        y = bot_position.y + math.sin(angle) * random_distance
      }
      
      local kamikaze = bot_surface.create_entity{
        name = kamikaze_name,
        position = bot_position,
        force = bot_force
      }
      
      if kamikaze then
        -- Make kamikaze invulnerable immediately
        kamikaze.destructible = false
        
        -- Track kamikaze bot to move to random position first
        kamikaze_bots[kamikaze] = {
          target = nil,
          target_pos = random_pos,
          created_tick = event.tick,
          bot_type = bot_type
        }
        
        -- Create initial warning effects
        bot_surface.create_entity{
          name = "flying-robot-damaged-explosion",
          position = bot_position
        }
      else
        -- If can't create bot, just explode
        bot_surface.create_entity{
          name = "laser-bot-emp-explosion",
          position = bot_position
        }
      end
    end
    
    -- Clean up kamikaze flag
    bots_going_kamikaze[bot_id] = nil
  end
end

-- Trigger kamikaze mode when construction or logistic robot takes damage below 10 health
script.on_event(defines.events.on_entity_damaged, function(event)
  if not (event.entity and event.entity.valid) then return end
  
  local bot = event.entity
  if bot.name == "laser-construction-robot" or bot.name == "laser-logistic-robot" then
    transform_to_kamikaze(bot, event)
  end
end)

-- Clean up state when normal bots are destroyed
script.on_event(defines.events.on_entity_died, function(event)
  if event.entity and event.entity.valid then
    local bot = event.entity
    if bot.name == "laser-construction-robot" or bot.name == "laser-logistic-robot" then
      local bot_id = bot.unit_number
      bot_fire_state[bot_id] = nil
      bots_going_kamikaze[bot_id] = nil
      bot_last_enemy_contact[bot_id] = nil
      laser_bots[bot_id] = nil
    end
  end
end)

-- Clean up state when normal bots are mined
script.on_event(defines.events.on_player_mined_entity, function(event)
  if event.entity and event.entity.valid then
    local bot = event.entity
    if bot.name == "laser-construction-robot" or bot.name == "laser-logistic-robot" then
      local bot_id = bot.unit_number
      bot_fire_state[bot_id] = nil
      bots_going_kamikaze[bot_id] = nil
      bot_last_enemy_contact[bot_id] = nil
      laser_bots[bot_id] = nil
    end
  end
end)

-- Rebuild laser bots tracking on init (in case mod was added to existing save)
script.on_init(function()
  for _, surface in pairs(game.surfaces) do
    local construction_bots = surface.find_entities_filtered{
      name = "laser-construction-robot",
      type = "construction-robot"
    }
    local logistic_bots = surface.find_entities_filtered{
      name = "laser-logistic-robot",
      type = "logistic-robot"
    }
    
    for _, bot in pairs(construction_bots) do
      laser_bots[bot.unit_number] = bot
    end
    for _, bot in pairs(logistic_bots) do
      laser_bots[bot.unit_number] = bot
    end
  end
end)

-- Rebuild on configuration change
script.on_configuration_changed(function()
  for _, surface in pairs(game.surfaces) do
    local construction_bots = surface.find_entities_filtered{
      name = "laser-construction-robot",
      type = "construction-robot"
    }
    local logistic_bots = surface.find_entities_filtered{
      name = "laser-logistic-robot",
      type = "logistic-robot"
    }
    
    for _, bot in pairs(construction_bots) do
      laser_bots[bot.unit_number] = bot
    end
    for _, bot in pairs(logistic_bots) do
      laser_bots[bot.unit_number] = bot
    end
  end
end)
