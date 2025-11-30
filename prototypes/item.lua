local item = table.deepcopy(data.raw.item["construction-robot"])

item.name = "laser-construction-robot"
item.place_result = "laser-construction-robot"
item.order = "a[robot]-b[laser]"
item.stack_size = 50

data:extend({ item })
