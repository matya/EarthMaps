local Silo = {}

local Config = require("config")
local Utils = require("scripts/utils")
local Surface = require("scripts/surface")

local world
local pre_place_silo

-- ============================================================================

local function disableSiloUsingEvent( event )
  local city = Utils.findSiloByUnitNumber( event.rocket_silo.unit_number )
  if city and city.rocket_silo and city.rocket_silo.entity then
    city.rocket_silo.entity.active = false
    city.rocket_silo.entity.operable = false
  end
end

-------------------------------------------------------------------------------

local function enableSilo( rocket_silo )
  if rocket_silo then
    rocket_silo.entity.active = true
    rocket_silo.entity.operable = true
  end
end

-------------------------------------------------------------------------------

local function enableSilos()
  for index = 1,  #storage.world.city_names do
    local city = storage.world.cities[storage.world.city_names[index]]
    if city.rocket_silo and city.rocket_silo.entity then
      city.rocket_silo.entity.active = true
      city.rocket_silo.entity.operable = true
    end
  end
end

-------------------------------------------------------------------------------

-- loop through forces, enabling silo crafting
local function enableSiloCrafting()
  if Utils.getStartupSetting( "em_team_coop" ) then
    for _, city in pairs( storage.world.cities ) do
      local force      = game.forces[city.name]
      local recipe     = force.recipes[Config.ROCKET_SILO]
      local technology = force.technologies[Config.ROCKET_SILO]

      if technology.researched then
        if not recipe.enabled then
          recipe.enabled = true
          game.print { "", { "em.text_mod_name" }, " ", { "em.text_silo_crafting_enabled" } }
        end
      end
    end
  end
end

-------------------------------------------------------------------------------

local function setupForDevMode( rocket_silo )
  if rocket_silo == nil then return end
  rocket_silo.rocket_parts = 99 -- setting to 100 will "launch" the rocket and return to 0.
  rocket_silo.insert({ name = "rocket-fuel",           count =  9 })  -- setting all of these to 100 will "launch" the rocket and return to 0.
  rocket_silo.insert({ name = "low-density-structure", count = 10 })
  rocket_silo.insert({ name = "processing-unit",        count = 10 })

  local surface  = rocket_silo.surface
  local position = rocket_silo.position
  local substation_entity = {
    name = "substation",
    position = Utils.positionAdd( position, { 0, -10 }),
    force = rocket_silo.force,
    create_build_effect_smoke = false
  }
  surface.create_entity( substation_entity )

  local energy_entity = {
    name = "electric-energy-interface",
    position = Utils.positionAdd( position, { 0, -12 }),
    force = rocket_silo.force,
    create_build_effect_smoke = false
  }
  surface.create_entity( energy_entity )
end

-------------------------------------------------------------------------------

local function emptyRocketLaunched()
  local remaining_launches = Utils.calculateRemainingLaunches()
  if remaining_launches > 0 then
    game.print { "", { "em.text_mod_name" }, " ", { "em.text_empty_rocket" } }
    game.print { "", { "em.text_mod_name" }, " ", tostring(remaining_launches, { "em.text_more_rockets" }), "" }
  end
end

-------------------------------------------------------------------------------

local function showLaunchedMessage( city, launches )
  game.print { "", { "em.text_mod_name" }, " ", tostring( launches ), { "em.text_rockets_launched" }, "" }
  if city.name then
    game.print { "", { "em.text_mod_name" }, " ", { "em.text_rocket_launched_from" }, city.name, "" }
  end
end

-------------------------------------------------------------------------------

local function getThisRocketSilo( event )
  local city = {}
  local this_rocket_silo = nil
  if pre_place_silo == Config.NONE or pre_place_silo == Config.SINGLE then
    this_rocket_silo = storage.world.rocket_silo
  elseif pre_place_silo == Config.ALL
     and storage.world.cities[storage.world.city_names[1]].rocket_silo
     and storage.world.cities[storage.world.city_names[1]].rocket_silo.entity then
    -- ensures a rocket silo exists for any city
    city = Utils.findSiloByUnitNumber( event.rocket_silo.unit_number )
    this_rocket_silo = city.rocket_silo
     -- if not found, create minimal structure to prevent future errors
    if this_rocket_silo == nil then
      this_rocket_silo = {}
    end
    if this_rocket_silo.entity.valid == false then
      this_rocket_silo.entity = nil
    end
  end
  return city, this_rocket_silo
end

-------------------------------------------------------------------------------

local function countRocketLaunched( event, this_rocket_silo, remaining_launches )
  game.print( { "", { "em.text_mod_name" }, " ", tostring( remaining_launches ), { "em.text_more_rockets" }, "" } )
  if pre_place_silo == Config.ALL then
    local max_launches = Utils.calculateMaxLaunches( pre_place_silo )
    if this_rocket_silo.launches_this_silo >= max_launches then
      disableSiloUsingEvent( event )
    end
    -- if the value of 'launches_this_silo' is 1, it is a new silo 'unlocked'.  Enable other silos that have been unlocked.
    if this_rocket_silo.launches_this_silo == 1 then
      Silo.checkEnablingSilos( max_launches )
    end
  end
end

-------------------------------------------------------------------------------

local function allRocketLaunched()
  enableSiloCrafting() -- Reenable silo crafting (this will check if the recipe is already disabled)
  if pre_place_silo == Config.ALL then -- re-enable all silos
    enableSilos()
  end
  if not game.finished then
    game.set_game_state( {
      game_finished = true,
      player_won = true,
      can_continue = true
    } )
  end
end

-------------------------------------------------------------------------------

local function createSilo( surface, city )
  local offset_position = Utils.positionAdd( city.position, Config.SILO_OFFSET )

  --  if settings is global co-op, set silo force to city force
  local silo_force = world.force
  if settings.startup.em_team_coop.value == true then
    log( "team coop - city.force" )
    silo_force = city.force
  else
    log( "not team coop - starting city force" )
    silo_force = world.spawn_city.force
  end


  ---@type LuaSurface.create_entity_param
  local build_params = {
    name = Config.ROCKET_SILO_ENTITY,
    force = silo_force,
    position = offset_position,
    move_stuck_players = true,
    raise_built = true,
    create_build_effect_smoke = false
  }

  local rocket_silo = Surface.forceBuildParams( surface, build_params )
  if not rocket_silo then
    Utils.print("WARNING: Failed to build rocket_silo: " .. city.name .. " " .. Utils.positionToStr(build_params.position))
    return --It really shouldn't fail at this point.
  end
  rocket_silo.destructible = false

  Utils.print("Created rocket silo: " .. city.name .. " " .. Utils.positionToStr(build_params.position))

  return rocket_silo
end

-------------------------------------------------------------------------------

function Silo.onCityGenerated( event )
  if pre_place_silo == Config.NONE then return end
  local rocket_silo = nil

  local city = world.cities[event.city_name]
    if pre_place_silo == Config.ALL then
      rocket_silo = createSilo( event.surface, city )
      if rocket_silo then
        city.rocket_silo.entity = rocket_silo
      end
    elseif pre_place_silo == Config.SINGLE and event.city_name == storage.world.silo_city.name then
      rocket_silo = createSilo( event.surface, city )
      if rocket_silo then
        city.rocket_silo = {}
        city.rocket_silo.entity = rocket_silo
      end
    end

    if settings.startup.em_dev_mode then
      setupForDevMode( rocket_silo )
    end

end

-------------------------------------------------------------------------------

function Silo.onCityCharted( event )
  local city = world.cities[event.city_name]
  local rocket_silo = city.rocket_silo and city.rocket_silo.entity

  if ( rocket_silo and rocket_silo.valid ) then
    Surface.placeTiles( event.surface, rocket_silo , "hazard-concrete-right" )
    if pre_place_silo == Config.SINGLE then
      local tag = {
        icon = { type = "item", name = Config.ROCKET_SILO },
        position = city.rocket_silo.entity.position,
        text = "   Rocket Silo"
      }
      world.force.add_chart_tag( event.surface, tag )
    end
  end
end

-------------------------------------------------------------------------------

function Silo.onRocketLaunched( event )
  local rocket_silo = storage.world.rocket_silo
  if not rocket_silo or pre_place_silo == Config.NONE then return end
  local city = {}
  local this_rocket_silo = nil

  -- no longer valid (v2.0) to launch an empty rocket.
  -- if not rocket.has_items_inside() then
  --   emptyRocketLaunched()
  --   return
  -- end

  city, this_rocket_silo = getThisRocketSilo( event )

  if this_rocket_silo == nil then return end -- catches initialization / migration errors
  if this_rocket_silo.launches_this_silo == nil then this_rocket_silo.launches_this_silo = 0 end -- fix for custom silos

  this_rocket_silo.launches_this_silo = this_rocket_silo.launches_this_silo + 1
  rocket_silo.total_launches = rocket_silo.total_launches + 1
  showLaunchedMessage( city, rocket_silo.total_launches )

  local remaining_launches = Utils.calculateRemainingLaunches()
  if remaining_launches > 0 then
    countRocketLaunched( event, this_rocket_silo, remaining_launches )
  else -- remaining launches <= 0
    allRocketLaunched()
  end
end

-------------------------------------------------------------------------------

function Silo.onResearchFinished(event)
  if not event then return end
  if not event.research then return end
  -- local rocket_silo = getRocketSiloData()
  local rocket_silo = storage.world.rocket_silo
  if not rocket_silo or pre_place_silo == Config.NONE then return end
  -- do not disable if required launches has been reached.
  if Utils.calculateRemainingLaunches() <= 0 then return end

  local recipes = event.research.force.recipes
  if recipes[Config.ROCKET_SILO] then
    -- log("Disabling Silo recipe ")
    recipes[Config.ROCKET_SILO].enabled = false
  end
end

-------------------------------------------------------------------------------

function Silo.setPrePlacedSilo( pre_place_silo_value )
  pre_place_silo = pre_place_silo_value
end

-------------------------------------------------------------------------------

-- loop through silos, find 'launches_this_silo' > 0 and if less than max_launches enable each
function Silo.checkEnablingSilos( max_launches )
  for index = 1,  #storage.world.city_names do
    local city = storage.world.cities[storage.world.city_names[index]]
    if city.rocket_silo and city.rocket_silo.launches_this_silo
      and city.rocket_silo.launches_this_silo > 0 and city.rocket_silo.launches_this_silo < max_launches then
      enableSilo( city.rocket_silo )
    end
  end
end

-------------------------------------------------------------------------------

function Silo.onInit()
  pre_place_silo = storage.settings.startup.em_pre_place_silo.value
  storage.world.rocket_silo = {
    total_launches = 0,
    launches_this_silo = 0
  }

  if pre_place_silo == Config.ALL then
    remote.call("silo_script", "set_no_victory", true)
    local required_launches = #storage.world.city_names
    storage.world.rocket_silo.required_launches = required_launches
    for index = 1,  required_launches do
      local city = storage.world.cities[storage.world.city_names[index]]
      city.rocket_silo = {}
      city.rocket_silo.launches_this_silo = 0
    end
  elseif pre_place_silo == Config.SINGLE then
    remote.call("silo_script", "set_no_victory", true)
    storage.world.rocket_silo.required_launches = 1
  else -- NONE or nil
    storage.world.rocket_silo.required_launches = 0
  end

  world = storage.world
end

-------------------------------------------------------------------------------

function Silo.onLoad()
  if storage.settings and storage.settings.startup.em_pre_place_silo then
    pre_place_silo = storage.settings.startup.em_pre_place_silo.value
  end
  world = storage.world
end

-- ============================================================================

return Silo
