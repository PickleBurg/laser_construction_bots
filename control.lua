-- Track firing state for normal bots
local bot_fire_state = {}

-- Track bots that are transitioning to kamikaze (prevent multiple triggers)
local bots_going_kamikaze = {}

-- Track kamikaze bots and their targets for manual movement
local kamikaze_bots = {}

-- Track last enemy contact time for each bot
local bot_last_enemy_contact = {}

-- Function to get current damage upgrade level
local function get_damage_level(force)
  for level = 10, 1, -1 do
    if force.technologies["laser-construction-bots-damage-" .. level] and 
       force.technologies["laser-construction-bots-damage-" .. level].researched then
      return level
    end
  end
  return 0
end

-- Function to get current cooldown upgrade level
local function get_cooldown_level(force)
  for level = 10, 1, -1 do
    if force.technologies["laser-construction-bots-cooldown-" .. level] and 
       force.technologies["laser-construction-bots-cooldown-" .. level].researched then
      return level
    end
  end
  return 0
end

-- Function to calculate laser damage based on upgrade level
local function get_laser_damage(force)
  local level = get_damage_level(force)
  -- Base: 10, Max: 50 (increases by 4 per level)
  return 10 + (level * 4)
end

-- Function to calculate cooldown based on upgrade level
local function get_laser_cooldown(force)
  local level = get_cooldown_level(force)
  -- Base: 300 ticks (5s), Max: 0 ticks (reduces by 30 per level)
  return math.max(0, 300 - (level * 30))
end

-- Normal laser construction bots
script.on_nth_tick(10, function(event)
  local current_tick = event.tick
  
  for _, surface in pairs(game.surfaces) do
    local bots = surface.find_entities_filtered{
      name = "laser-construction-robot",
      type = "construction-robot"
    }
    
    for _, bot in pairs(bots) do
      if bot.valid and not bots_going_kamikaze[bot.unit_number] then
        local bot_id = bot.unit_number

        -- Initialize bot state if new
        if not bot_fire_state[bot_id] then
          bot_fire_state[bot_id] = {
            fire_time = 0,
            cooldown_until = 0,
            in_roboport = false,
            random_cooldown = math.random(60, 180)  -- Random cooldown between 1-3 seconds
          }
        end

        local state = bot_fire_state[bot_id]
        
        -- Get current research bonuses
        local laser_damage = get_laser_damage(bot.force)
        local laser_cooldown = get_laser_cooldown(bot.force)
        
        -- Normal laser firing logic
        local enemies = surface.find_entities_filtered{
          position = bot.position,
          radius = 15,
          force = "enemy",
          limit = 1
        }

        if enemies[1] and enemies[1].valid and enemies[1].health and bot.energy > 1000 then
          local target = enemies[1]
          local currently_in_roboport = bot.logistic_cell ~= nil and bot.to_be_looted == false

          -- Update last enemy contact time
          bot_last_enemy_contact[bot_id] = current_tick

          if currently_in_roboport and not state.in_roboport then
            state.cooldown_until = 0
            state.fire_time = 0
          end

          state.in_roboport = currently_in_roboport

          if not currently_in_roboport and current_tick >= state.cooldown_until then
            if state.fire_time >= 120 then
              -- After firing for 2 seconds, cooldown based on research with random offset
              state.cooldown_until = current_tick + laser_cooldown + math.random(-30, 30)
              state.fire_time = 0
            else
              surface.create_entity{
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
          end
        else
          -- No enemy in range - check if we should reset cooldown
          if bot_last_enemy_contact[bot_id] then
            local time_since_enemy = current_tick - bot_last_enemy_contact[bot_id]
            
            -- If no enemy for 2 seconds (120 ticks), set random cooldown
            if time_since_enemy >= 120 then
              state.cooldown_until = current_tick + state.random_cooldown
              state.random_cooldown = math.random(60, 180)  -- New random cooldown for next time
              bot_last_enemy_contact[bot_id] = nil
            end
          end
        end
      end
    end
  end
end)

-- Move kamikaze bots toward their targets (EVERY TICK for smooth movement)
script.on_nth_tick(1, function(event)
  local current_tick = event.tick
  
  for kamikaze, data in pairs(kamikaze_bots) do
    if not (kamikaze and kamikaze.valid) then
      kamikaze_bots[kamikaze] = nil
      goto continue
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
    local has_timed_out = time_alive > 200  -- 200 ticks = ~3.3 seconds timeout
    
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
    if current_tick % 15 == 0 then  -- Less frequent smoke (every 15 ticks instead of 5)
      kamikaze.surface.create_trivial_smoke{
        name = "light-smoke",  -- Changed to light-smoke for white steam effect
        position = kamikaze.position
      }
    end
    
    if current_tick % 3 == 0 then  -- Sparks every 3 ticks
      kamikaze.surface.create_entity{
        name = "flying-robot-damaged-explosion",
        position = kamikaze.position
      }
    end
    
    -- EXPLODE when close enough to target (2 tiles) OR timed out
    if dist < 2.0 or has_timed_out then
      -- Play crash animation - robot exploding
      kamikaze.surface.create_entity{
        name = "construction-robot-explosion",
        position = kamikaze.position
      }
      
      -- Small delay visual - sparks burst
      for i = 1, 5 do
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
        radius = 12
      }
      
      for _, entity in pairs(entities_in_range) do
        -- Check entity validity FIRST before accessing any properties
        if not entity.valid then
          goto skip_entity
        end
        
        -- Only affect enemies, NOT players or friendly forces
        if entity.force.name == "enemy" and entity.health and entity.type ~= "character" then
          -- Apply minimal damage (5 electric damage) - WORKS ON ALL ENEMIES
          entity.damage(5, kamikaze.force, "electric")
          
          -- Check if entity is still valid after damage (might have been destroyed)
          if not entity.valid then
            goto skip_entity
          end
          
          -- Apply EMP sticker for visual effect and STRONG slowdown (ONLY IF ENTITY CAN ACCEPT STICKERS)
          -- Check if entity has sticker_box (only units like biters/spitters can accept stickers)
          if entity.prototype and entity.prototype.sticker_box then
            pcall(function()
              if entity.valid then  -- Double-check validity inside pcall
                entity.surface.create_entity{
                  name = "emp-sticker",
                  position = entity.position,
                  target = entity
                }
              end
            end)
          end
          
          -- Create electric sparks on each affected enemy - WORKS ON ALL ENEMIES
          if entity.valid then  -- Check validity again before creating sparks
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
      -- FIXED SPEED - matches default construction robot speed, no research scaling
      local base_speed = 0.05  -- Fixed at default construction robot speed
      local move_speed = base_speed
      
      local move_x = (dx / dist) * move_speed
      local move_y = (dy / dist) * move_speed
      kamikaze.teleport{x = kamikaze.position.x + move_x, y = kamikaze.position.y + move_y}
    end
    
    ::continue::
  end
end)

-- Trigger kamikaze mode when construction robot takes damage below 10 health
script.on_event(defines.events.on_entity_damaged, function(event)
  if not (event.entity and event.entity.valid and event.entity.name == "laser-construction-robot") then return end
  
  local bot = event.entity
  local bot_id = bot.unit_number
  
  -- Prevent multiple kamikaze triggers for the same bot
  if bots_going_kamikaze[bot_id] then return end
  
  -- Check if health is below 10
  if bot.health <= 10 then
    -- Mark this bot as transitioning to kamikaze
    bots_going_kamikaze[bot_id] = true
    
    -- Store bot info before it's destroyed
    local bot_position = {x = bot.position.x, y = bot.position.y}
    local bot_surface = bot.surface
    local bot_force = bot.force
    
    -- Find enemies, prioritize biters/worms over spawners (min 2 tiles, max 15 tiles)
    -- ONLY target enemy force, never players
    local enemies = bot_surface.find_entities_filtered{
      position = bot_position,
      radius = 15,
      force = "enemy"
    }
    
    -- Separate enemies by priority: units (biters/spitters), turrets (worms), then spawners
    local priority_targets = {}  -- Units and turrets
    local low_priority_targets = {}  -- Spawners
    
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
    bot.destroy()
    
    -- Then create kamikaze unit
    if target and target.valid then
      local kamikaze = bot_surface.create_entity{
        name = "laser-construction-robot-kamikaze",
        position = bot_position,
        force = bot_force
      }
      
      if kamikaze then
        -- Make kamikaze invulnerable immediately
        kamikaze.destructible = false
        
        -- Track kamikaze bot for manual movement control (NO VISUAL MARKERS)
        kamikaze_bots[kamikaze] = {
          target = target,
          target_pos = {x = target.position.x, y = target.position.y},
          created_tick = event.tick
        }
        
        -- Create initial warning effects - BIG explosion and sound
        bot_surface.create_entity{
          name = "flying-robot-damaged-explosion",
          position = bot_position
        }
        
        -- NO red circle or line - stealth kamikaze mode!
      end
    else
      -- Target too close (< 2 tiles), move to a random point between 3-15 tiles away
      local angle = math.random() * 2 * math.pi
      local random_distance = 3 + math.random() * 12  -- Random distance between 3 and 15
      local random_pos = {
        x = bot_position.x + math.cos(angle) * random_distance,
        y = bot_position.y + math.sin(angle) * random_distance
      }
      
      local kamikaze = bot_surface.create_entity{
        name = "laser-construction-robot-kamikaze",
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
          created_tick = event.tick
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
end)

-- Clean up state when normal bots are destroyed
script.on_event(defines.events.on_entity_died, function(event)
  if event.entity and event.entity.valid and event.entity.name == "laser-construction-robot" then
    local bot_id = event.entity.unit_number
    bot_fire_state[bot_id] = nil
    bots_going_kamikaze[bot_id] = nil
    bot_last_enemy_contact[bot_id] = nil
  end
end)

-- Clean up state when normal bots are mined
script.on_event(defines.events.on_player_mined_entity, function(event)
  if event.entity and event.entity.valid and event.entity.name == "laser-construction-robot" then
    local bot_id = event.entity.unit_number
    bot_fire_state[bot_id] = nil
    bots_going_kamikaze[bot_id] = nil
    bot_last_enemy_contact[bot_id] = nil
  end
end)
