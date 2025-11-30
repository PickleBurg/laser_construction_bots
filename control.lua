-- Only scan bots that are actually deployed, not in roboports
local function find_active_laser_bots(surface)
  return surface.find_entities_filtered{
    name = "laser-construction-robot",
    type = "construction-robot"
  }
end

-- Track firing state for each bot
local bot_fire_state = {}
-- fire_time: how many ticks the bot has been firing
-- cooldown_until: tick when cooldown ends
-- in_roboport: whether the bot is currently in a roboport

script.on_nth_tick(10, function(event)  -- Check every 10 ticks (balanced performance)
  local current_tick = event.tick
  
  for _, surface in pairs(game.surfaces) do
    local bots = surface.find_entities_filtered{
      name = "laser-construction-robot",
      type = "construction-robot"
    }
    
    for _, bot in pairs(bots) do
      -- ========== TESTING: INVINCIBILITY - REMOVE BEFORE RELEASE ==========
      if bot.valid then
        bot.destructible = false
      end
      -- ====================================================================
      
      if bot.valid and bot.energy > 1000 then  -- Higher threshold for more reliable firing
        local bot_id = bot.unit_number
        
        -- Initialize bot state if new
        if not bot_fire_state[bot_id] then
          bot_fire_state[bot_id] = {fire_time = 0, cooldown_until = 0, in_roboport = false}
        end
        
        local state = bot_fire_state[bot_id]
        
        -- Check if bot is in a roboport (has logistic cell and is charging)
        local currently_in_roboport = bot.logistic_cell ~= nil and bot.to_be_looted == false
        
        -- Reset cooldown if bot enters roboport (wasn't in, now is)
        if currently_in_roboport and not state.in_roboport then
          state.cooldown_until = 0
          state.fire_time = 0
        end
        
        -- Update roboport status
        state.in_roboport = currently_in_roboport
        
        -- Don't fire while in roboport
        if currently_in_roboport then
          goto continue
        end
        
        -- Check if bot is in cooldown
        if current_tick < state.cooldown_until then
          -- Bot is cooling down, skip firing
          goto continue
        end
        
        -- Find enemies
        local enemies = surface.find_entities_filtered{
          position = bot.position,
          radius = 15,
          force = "enemy",
          limit = 1
        }
        
        if enemies[1] and enemies[1].valid and enemies[1].health then
          local target = enemies[1]
          
          -- Fire for 2 seconds (120 ticks), then cooldown for 5 seconds (300 ticks)
          if state.fire_time >= 300 then
            -- Start cooldown period (300 ticks = 5 seconds)
            state.cooldown_until = current_tick + 120
            state.fire_time = 0
            goto continue
          end
          
          -- Fire laser with bot as source entity (updates position automatically)
          surface.create_entity{
            name = "laser-beam",
            position = bot.position,
            target = target,  -- Changed: use entity instead of position
            source = bot,     -- Changed: use entity instead of position
            duration = 10
          }
          
          -- Deal damage (reduced from turret to balance mobility)
          target.damage(10, bot.force, "laser", bot)
          
          -- Consume energy
          bot.energy = bot.energy - 1000
          
          -- Increment fire time
          state.fire_time = state.fire_time + 10  -- +10 because we check every 10 ticks
        end
        -- Note: Fire time does NOT reset when no enemies (cooldown persists)
        
        ::continue::
      end
    end
  end
end)

-- Clean up state table when bots are destroyed
script.on_event(defines.events.on_entity_died, function(event)
  if event.entity and event.entity.valid and event.entity.name == "laser-construction-robot" then
    bot_fire_state[event.entity.unit_number] = nil
  end
end)

-- Clean up state when bots are mined
script.on_event(defines.events.on_player_mined_entity, function(event)
  if event.entity and event.entity.valid and event.entity.name == "laser-construction-robot" then
    bot_fire_state[event.entity.unit_number] = nil
  end
end)
