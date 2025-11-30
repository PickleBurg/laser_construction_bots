data:extend({
  {
    type = "technology",
    name = "laser-construction-bots",
    icon = "__base__/graphics/technology/construction-robotics.png",
    icon_size = 256,
    prerequisites = {"construction-robotics", "laser"},
    effects = {
      {
        type = "unlock-recipe",
        recipe = "laser-construction-robot"
      }
    },
    unit = {
      count = 150,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1}
      },
      time = 30
    }
  }
})
