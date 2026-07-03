-- em_teleporter prototype entity
-- =============================================================================

local Config = require("config")
local ENTITY_PATH = "__EarthMaps__/graphics/entities/"

local em_teleporter = util.table.deepcopy(data.raw["lab"]["lab"])
em_teleporter.name = "em_teleporter"
em_teleporter.corpse = "big-remnants"
em_teleporter.minable = nil
em_teleporter.researching_speed = 0
em_teleporter.inputs = {}
em_teleporter.module_specification = nil
em_teleporter.dying_explosion = "explosion"
em_teleporter.energy_usage = Config.TP_MAX_ENERGY_STR
em_teleporter.energy_source = {
  type = "electric",
  usage_priority = "secondary-input",
  input_flow_limit = "100kW" -- slow charge rate
}
em_teleporter.off_animation = {
  layers = {
    {
      filename = ENTITY_PATH .. "market/market.png",
      width = 100,
      height = 110,
      scale = 1,
      hr_version = { filename = ENTITY_PATH .. "market/hr-market.png", width = 200, height = 220, scale = 0.5 }
    }
  }
}
em_teleporter.on_animation = {
  layers = {
    {
      filename = ENTITY_PATH .. "market/market.png",
      width = 100,
      height = 110,
      scale = 1,
      hr_version = { filename = ENTITY_PATH .. "market/hr-market.png", width = 200, height = 220, scale = 0.5 }
    }
  }
}

data:extend({ em_teleporter })
