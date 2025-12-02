local construction_item = table.deepcopy(data.raw.item["construction-robot"])
construction_item.name = "laser-construction-robot"
construction_item.place_result = "laser-construction-robot"
construction_item.order = "a[robot]-b[laser-construction]"
construction_item.stack_size = 50
construction_item.localised_description = {"item-description.laser-construction-robot"}

local logistic_item = table.deepcopy(data.raw.item["logistic-robot"])
logistic_item.name = "laser-logistic-robot"
logistic_item.place_result = "laser-logistic-robot"
logistic_item.order = "a[robot]-c[laser-logistic]"
logistic_item.stack_size = 50
logistic_item.localised_description = {"item-description.laser-logistic-robot"}

data:extend({ construction_item, logistic_item })
