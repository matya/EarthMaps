local Config = require("config")

local em_rocket_silo = util.table.deepcopy(data.raw["rocket-silo"][Config.ROCKET_SILO])
em_rocket_silo.name = Config.ROCKET_SILO_ENTITY
-- Make EarthMaps silos non-minable by removing inherited minable properties.
em_rocket_silo.minable = nil

data:extend({ em_rocket_silo })
