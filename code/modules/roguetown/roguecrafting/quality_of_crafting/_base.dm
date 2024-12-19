/datum/repeatable_crafting_recipe
	abstract_type = /datum/repeatable_crafting_recipe

	var/name = "Generic Recipe"
	var/atom/output
	var/output_amount = 1
	var/list/requirements = list()
	var/list/reagent_requirements = list()

	///this is the things we check for in our offhand ie herb pouch or something to repeat the craft
	var/list/offhand_repeat_check = list(/obj/item/storage/backpack/rogue)
	///if this is set we also check the floor on the ground
	var/check_around_owner = TRUE
	///this is the atom we need to start the process
	var/atom/starting_atom
	///this is the thing we need to hit to start
	var/atom/attacking_atom

	///our crafting difficulty
	var/craftdiff = 1
	///our skilltype
	var/datum/skill/skillcraft

	///the amount of time the atom in question spends doing this recipe
	var/craft_time = 1 SECONDS
	///do we put in hand?
	var/put_items_in_hand = TRUE
	///the time it takes to move an item from ground to hand
	var/ground_use_time = 0.2 SECONDS
	///the time it takes to move an item from storage to hand
	var/storage_use_time = 0.4 SECONDS
	///the time it takes to use reagents on the craft
	var/reagent_use_time = 0.8 SECONDS
	///our crafting message
	var/crafting_message
	///if we need to be on a table
	var/required_table = FALSE
	///intent we require
	var/datum/intent/required_intent
	///do we also use the attacking_atom in the recipe?
	var/uses_attacking_atom = FALSE
	///do we also count subtypes?
	var/subtypes_allowed = FALSE
	///list of types we pass before deletion to the child
	var/list/pass_types_in_end = list()

/datum/repeatable_crafting_recipe/proc/check_start(obj/item/attacked_item, obj/item/attacking_item, mob/user)
	if(!istype(attacked_item, attacking_atom))
		return FALSE

	if(required_intent && user.used_intent != required_intent)
		return FALSE

	var/obj/structure/table/table = locate(/obj/structure/table) in get_turf(attacking_atom)
	if(required_table && !table)
		return FALSE

	var/list/usable_contents = list()
	if(uses_attacking_atom)
		usable_contents |= attacked_item.type
		usable_contents[attacked_item.type]++

	for(var/obj/item/I in user.held_items)
		usable_contents |= I.type
		usable_contents[I.type]++

	var/obj/item/inactive_hand = user.get_inactive_held_item()
	if(is_type_in_list(inactive_hand, offhand_repeat_check))
		for(var/obj/item in inactive_hand.contents)
			usable_contents |= item.type
			usable_contents[item.type] ++

	if(check_around_owner)
		for(var/turf/listed_turf in range(1, user))
			for(var/obj/item in listed_turf.contents)
				usable_contents |= item.type
				usable_contents[item.type]++

	var/list/total_list = usable_contents
	for(var/path as anything in total_list)
		for(var/required_path as anything in requirements)
			if(!ispath(path, required_path))
				continue
			if(!subtypes_allowed && (path in subtypesof(required_path)))
				return FALSE
			if(total_list[path] < requirements[required_path])
				return FALSE

	if(length(reagent_requirements))
		var/list/reagent_values = list()
		for(var/obj/item/reagent_containers/container in user.held_items)
			for(var/datum/reagent/reagent as anything in container.reagents.reagent_list)
				reagent_values |= reagent.type
				reagent_values[reagent.type] += reagent.volume

		if(check_around_owner)
			for(var/turf/listed_turf in range(1, user))
				for(var/obj/item/reagent_containers/container in listed_turf.contents)
					for(var/datum/reagent/reagent as anything in container.reagents.reagent_list)
						reagent_values |= reagent.type
						reagent_values[reagent.type] += reagent.volume

		for(var/path in reagent_values)
			for(var/required_path as anything in reagent_requirements)
				if(!ispath(path, required_path))
					continue
				if(reagent_values[path] < reagent_requirements[required_path])
					return FALSE

	return TRUE

/datum/repeatable_crafting_recipe/proc/check_max_repeats(obj/item/attacked_item, obj/item/attacking_item, mob/user)
	var/list/usable_contents = list()
	if(uses_attacking_atom)
		usable_contents |= attacked_item.type
		usable_contents[attacked_item.type]++

	for(var/obj/item/I in user.held_items)
		usable_contents |= I.type
		usable_contents[I.type]++

	var/obj/item/inactive_hand = user.get_inactive_held_item()
	if(is_type_in_list(inactive_hand, offhand_repeat_check))
		for(var/obj/item in inactive_hand.contents)
			usable_contents |= item.type
			usable_contents[item.type] ++

	if(check_around_owner)
		for(var/turf/listed_turf in range(1, user))
			for(var/obj/item in listed_turf.contents)
				usable_contents |= item.type
				usable_contents[item.type]++

	var/max_crafts = 10000
	var/list/total_list = usable_contents
	for(var/path as anything in total_list)
		for(var/required_path as anything in requirements)
			if(!ispath(path, required_path))
				continue
			var/holder_max_crafts = FLOOR(total_list[path] / requirements[required_path], 1)
			if(holder_max_crafts < max_crafts)
				max_crafts = holder_max_crafts

	if(length(reagent_requirements))
		var/list/reagent_values = list()
		for(var/obj/item/reagent_containers/container in user.held_items)
			for(var/datum/reagent/reagent as anything in container.reagents.reagent_list)
				reagent_values |= reagent.type
				reagent_values[reagent.type] += reagent.volume

		if(check_around_owner)
			for(var/turf/listed_turf in range(1, user))
				for(var/obj/item/reagent_containers/container in listed_turf.contents)
					for(var/datum/reagent/reagent as anything in container.reagents.reagent_list)
						reagent_values |= reagent.type
						reagent_values[reagent.type] += reagent.volume

		for(var/path in reagent_values)
			for(var/required_path as anything in reagent_requirements)
				if(!ispath(path, required_path))
					continue
				var/holder_max_crafts = FLOOR(reagent_values[path] / reagent_requirements[required_path], 1)
				if(holder_max_crafts < max_crafts)
					max_crafts = holder_max_crafts


	return max_crafts

/datum/repeatable_crafting_recipe/proc/start_recipe(obj/item/attacked_item, obj/item/attacking_item, mob/user)
	var/max_crafts = check_max_repeats(attacked_item, attacking_item, user)
	var/actual_crafts = 1
	if(max_crafts > 1)
		actual_crafts = input(user, "How many [name] do you want to craft?", "Repeat Option", max_crafts) as null|num
	if(!actual_crafts)
		return
	actual_crafts = CLAMP(actual_crafts, 1, max_crafts)

	if(!istype(attacked_item, attacking_atom))
		return FALSE
	var/list/usable_contents = list()
	var/list/storage_contents = list()

	if(uses_attacking_atom && !QDELETED(attacked_item))
		usable_contents |= attacked_item

	for(var/obj/item/I in user.held_items)
		usable_contents |= I

	var/obj/item/inactive_hand = user.get_inactive_held_item()
	if(is_type_in_list(inactive_hand, offhand_repeat_check))
		for(var/obj/item in inactive_hand.contents)
			storage_contents |= item

	if(check_around_owner)
		for(var/turf/listed_turf in range(1, user))
			for(var/obj/item in listed_turf.contents)
				usable_contents |= item

	for(var/craft = 1 to actual_crafts)
		var/list/copied_requirements = requirements.Copy()
		var/list/copied_reagent_requirements = reagent_requirements.Copy()
		var/list/to_delete = list()

		var/obj/item/active_item = user.get_active_held_item()


		if(put_items_in_hand)
			if(isnull(active_item))
				for(var/obj/item/item in usable_contents)
					if(!length(copied_requirements))
						break
					if(!is_type_in_list(item, copied_requirements))
						continue
					user.visible_message("[user] starts picking up [item]", "You start picking up [item]")
					if(do_after(user, ground_use_time, target = item))
						user.put_in_active_hand(item)
						active_item = item
					break

			if(isnull(active_item))
				for(var/obj/item/item in storage_contents)
					if(!length(copied_requirements))
						break
					if(!is_type_in_list(item, copied_requirements))
						continue
					to_chat(user, "You start grabbing [item] from your bag.")
					if(do_after(user, storage_use_time, target = item))
						user.put_in_active_hand(item)
						active_item = item
					break

			if(!is_type_in_list(active_item, copied_requirements))
				move_items_back(to_delete, user)
				return

			for(var/requirement in copied_requirements)
				if(!istype(active_item, requirement))
					continue
				copied_requirements[requirement]--
				if(copied_requirements[requirement] <= 0)
					copied_requirements -= requirement
				usable_contents -= active_item
				to_delete += active_item
				active_item.forceMove(locate(1,1,1)) ///the fucking void of items

		for(var/obj/item/item in usable_contents)
			if(!length(copied_requirements))
				break
			if(!is_type_in_list(item, copied_requirements))
				continue
			user.visible_message("[user] starts picking up [item]", "You start picking up [item]")
			if(do_after(user, ground_use_time, target = item))
				if(put_items_in_hand)
					user.put_in_active_hand(item)
				for(var/requirement in copied_requirements)
					if(!istype(item, requirement))
						continue
					copied_requirements[requirement]--
					if(copied_requirements[requirement] <= 0)
						copied_requirements -= requirement
					usable_contents -= item
					to_delete += item
					item.forceMove(locate(1,1,1)) ///the fucking void of items
			else
				break

		for(var/obj/item/item in storage_contents)
			if(!length(copied_requirements))
				break
			if(!is_type_in_list(item, copied_requirements))
				continue
			to_chat(user, "You start grabbing [item] from your bag.")
			if(do_after(user, storage_use_time, target = item))
				if(put_items_in_hand)
					user.put_in_active_hand(item)
				for(var/requirement in copied_requirements)
					if(!istype(item, requirement))
						continue
					copied_requirements[requirement]--
					if(copied_requirements[requirement] <= 0)
						copied_requirements -= requirement
					storage_contents -= item
					to_delete += item
					item.forceMove(locate(1,1,1)) ///the fucking void of items
			else
				break

		if(length(copied_reagent_requirements))
			for(var/obj/item/reagent_containers/container in storage_contents)
				for(var/required_path as anything in copied_reagent_requirements)
					var/reagent_value = container.reagents.get_reagent_amount(required_path)
					if(!reagent_value)
						continue
					var/turf/container_loc = get_turf(container)
					var/stored_pixel_x = container.pixel_x
					var/stored_pixel_y = container.pixel_y
					user.visible_message("[user] starts to incorporate some liquid into [name].", "You start to pour some liquid into [name].")
					if(put_items_in_hand)
						if(!do_after(user, storage_use_time, target = container))
							continue
						user.put_in_active_hand(container)
					if(istype(container, /obj/item/reagent_containers/glass/bottle))
						var/obj/item/reagent_containers/glass/bottle/bottle = container
						if(bottle.closed)
							bottle.rmb_self(user)
					if(!do_after(user, reagent_use_time, target = container))
						continue
					playsound(get_turf(user), pick(container.poursounds), 100, TRUE)
					if(reagent_value < copied_reagent_requirements[required_path]) //reagents are lost regardless as you kinda already poured them in no unpouring.
						container.reagents.remove_reagent(required_path, reagent_value)
						copied_reagent_requirements[required_path] -= reagent_value
					else
						container.reagents.remove_reagent(required_path, copied_reagent_requirements[required_path])
						copied_reagent_requirements -= required_path
					if(put_items_in_hand)
						user.transferItemToLoc(container, container_loc, TRUE)
						container.pixel_x = stored_pixel_x
						container.pixel_y = stored_pixel_y

			for(var/obj/item/reagent_containers/container in usable_contents)
				for(var/required_path as anything in copied_reagent_requirements)
					var/reagent_value = container.reagents.get_reagent_amount(required_path)
					if(!reagent_value)
						continue
					var/turf/container_loc = get_turf(container)
					var/stored_pixel_x = container.pixel_x
					var/stored_pixel_y = container.pixel_y
					user.visible_message("[user] starts to incorporate some liquid into [name].", "You start to pour some liquid into [name].")
					if(put_items_in_hand)
						if(!do_after(user, ground_use_time, target = container))
							continue
						user.put_in_active_hand(container)
					if(istype(container, /obj/item/reagent_containers/glass/bottle))
						var/obj/item/reagent_containers/glass/bottle/bottle = container
						if(bottle.closed)
							bottle.rmb_self(user)
					if(!do_after(user, reagent_use_time, target = container))
						continue
					playsound(get_turf(user), pick(container.poursounds), 100, TRUE)
					if(reagent_value < copied_reagent_requirements[required_path]) //reagents are lost regardless as you kinda already poured them in no unpouring.
						container.reagents.remove_reagent(required_path, reagent_value)
						copied_reagent_requirements[required_path] -= reagent_value
					else
						container.reagents.remove_reagent(required_path, copied_reagent_requirements[required_path])
						copied_reagent_requirements -= required_path
					if(put_items_in_hand)
						user.transferItemToLoc(container, container_loc, TRUE)
						container.pixel_x = stored_pixel_x
						container.pixel_y = stored_pixel_y

		if(!length(copied_requirements) && !length(copied_reagent_requirements))
			if(crafting_message)
				user.visible_message("[user] [crafting_message].", "You [crafting_message].")
			if(do_after(user, craft_time, target = attacked_item))
				var/prob2craft = 25
				var/prob2fail = 1
				if(craftdiff)
					prob2craft -= (25 * craftdiff)
				if(skillcraft)
					if(user.mind)
						prob2craft += (user.mind.get_skill_level(skillcraft) * 25)
				else
					prob2craft = 100
				if(isliving(user))
					var/mob/living/L = user
					if(L.STALUC > 10)
						prob2fail = 0
					if(L.STALUC < 10)
						prob2fail += (10-L.STALUC)
					if(L.STAINT > 10)
						prob2craft += ((10-L.STAINT)*-1)*2
				if(prob2craft < 1)
					to_chat(user, "<span class='danger'>I lack the skills for this...</span>")
					move_items_back(to_delete, user)
					return
				else
					prob2craft = CLAMP(prob2craft, 5, 99)
					if(prob(prob2fail)) //critical fail
						to_chat(user, "<span class='danger'>MISTAKE! I've completely fumbled the crafting of \the [name]!</span>")
						move_items_back(to_delete, user)
						return
					if(!prob(prob2craft))
						if(user.client?.prefs.showrolls)
							to_chat(user, "<span class='danger'>I've failed to craft \the [name]. (Success chance: [prob2craft]%)</span>")
							move_items_back(to_delete, user)
							continue
						to_chat(user, "<span class='danger'>I've failed to craft \the [name].</span>")
						continue

				if(put_items_in_hand)
					active_item = null

				for(var/spawn_count = 1 to output_amount)
					var/obj/item/new_item = new output(get_turf(user))
					if(length(pass_types_in_end))
						var/list/parts = list()
						for(var/obj/item/listed as anything in to_delete)
							if(!is_type_in_list(listed, pass_types_in_end))
								continue
							parts += listed
						new_item.CheckParts(parts)
						parts = null

				for(var/obj/item/deleted in to_delete)
					to_delete -= deleted
					qdel(deleted)

			else
				move_items_back(to_delete, user)
				return
		else
			move_items_back(to_delete, user)
			return

/datum/repeatable_crafting_recipe/proc/move_items_back(list/items, mob/user)
	for(var/obj/item/item in items)
		item.forceMove(user.drop_location())
