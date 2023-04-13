ModMaterialsFileAdd("mods/conway_mod/files/mat.xml")
dofile_once("mods/conway_mod/nsew/load.lua")("mods/conway_mod")

local ffi = require 'ffi'
local world_ffi = require("nsew.world_ffi")

function nearby_mats( matx, maty, mat_name )
	local search_result = 0
	local search_count = 0
	local offset_y = math.floor(maty) - 1
	local grid_world = world_ffi.get_grid_world()
	local chunk_map = grid_world.vtable.get_chunk_map(grid_world)
	while search_count < 9 do
		local offset_x = math.floor(matx) + ((search_count % 3) - 1)
		local pcell = world_ffi.get_cell(chunk_map, offset_x, offset_y)
		if pcell[0] ~= nil then
			local mat_id = CellFactory_GetName(world_ffi.get_material_id(pcell[0].vtable.get_material(pcell[0])))
			if mat_id == mat_name then search_result = search_result + 1 end
		end
		if search_count % 3 == 2 then offset_y = offset_y + 1 end
		search_count = search_count + 1
	end
	return search_result
end

function table_insert_9x9( mid_x, mid_y )
	local x_off_list = {-1, -1, -1, 0, 0, 1, 1, 1 }
	local y_off_list = {-1, 0, 1, -1, 1, -1, 0, 1}
	for i=1, 8, 1 do
		local position_insert = { pos_x = mid_x + x_off_list[i], pos_y = mid_y + y_off_list[i]}
		local has_found = false
		for i, spot in ipairs(table_of_positions) do
			if spot.pos_x == position_insert.pos_x and spot.pos_y == position_insert.pos_y then
				has_found = true
				break
			end
		end
		if not has_found then
			table.insert(table_of_positions, position_insert)
		end
	end
end

function OnWorldPostUpdate()
	
	local player = EntityGetWithName("DEBUG_NAME:player")
	local i2c_id = EntityGetFirstComponentIncludingDisabled( player, "Inventory2Component")
	local item_id = ComponentGetValue2( i2c_id, "mActiveItem" )

	--gui = gui or GuiCreate()   unsure if I want to yet. just gonna leave it here until I decide to
	
	table_of_positions = table_of_positions or {}
	
	local cc_id = EntityGetFirstComponentIncludingDisabled( player, "ControlsComponent" )
	local ml_down = ComponentGetValue2( cc_id, "mButtonDownLeftClick" )
	local mr_down = ComponentGetValue2( cc_id, "mButtonDownRightClick" )
	local kick_frame = ComponentGetValue2( cc_id, "mButtonFrameKick" )
	local should_simulate = tonumber(GlobalsGetValue( "Conway_Extol_Sim", "0" ))
	if kick_frame == GameGetFrameNum() then
		if should_simulate == 1 then
			GlobalsSetValue( "Conway_Extol_Sim", "0" )
			should_simulate = 0
		else
			GlobalsSetValue( "Conway_Extol_Sim", "1" )
			should_simulate = 1
		end
	end
	local grid_world = world_ffi.get_grid_world()
	local chunk_map = grid_world.vtable.get_chunk_map(grid_world)
	local x, y = DEBUG_GetMouseWorld()
	x = math.floor(x)
	y = math.floor(y)
	if world_ffi.chunk_loaded(chunk_map,x,y) then
		if EntityGetName(item_id) == "CONWAY_STONE" then
			if ml_down and should_simulate == 0 then
				local pos_ptr = world_ffi.get_cell(chunk_map, x, y)
				if pos_ptr[0] == nil then
					local mat_ptr = world_ffi.get_material_ptr(CellFactory_GetType("conway_life_mat"))
					local pixel = world_ffi.construct_cell(grid_world, x, y, mat_ptr, pos_ptr[0])
					pos_ptr[0] = pixel
					local place_pos = { pos_x = x, pos_y = y }
					table.insert( table_of_positions, place_pos )
					table_insert_9x9( x, y )
					GamePrint("Placed")
				end
			elseif mr_down then
				local pos_ptr = world_ffi.get_cell(chunk_map, x, y)
				if pos_ptr[0] ~= nil then
					local mat_id = CellFactory_GetName(world_ffi.get_material_id(pos_ptr[0].vtable.get_material(pos_ptr[0])))
					if mat_id == "conway_life_mat" then
						local pixel = world_ffi.remove_cell(grid_world, pos_ptr[0], x, y, true)
						pos_ptr[0] = pixel
						table_insert_9x9( x, y )
					end
				end
			end
		end
	end
	
	if should_simulate == 0 or #table_of_positions == 0 then
		GlobalsSetValue( "Conway_Extol_Sim", "0" )
		return
	end

	local table_of_results = {}

	for i=#table_of_positions,1,-1 do
		local index = table_of_positions[i]
		if world_ffi.chunk_loaded(chunk_map,index.pos_x,index.pos_y) then
			if world_ffi.chunk_loaded(chunk_map,index.pos_x,index.pos_y) then
				local pos_ptr = world_ffi.get_cell(chunk_map, index.pos_x, index.pos_y)
				if pos_ptr[0] ~= nil then
					local nearby_count = nearby_mats(index.pos_x, index.pos_y, "conway_life_mat")
					local result = {index.pos_x, index.pos_y, nearby_count}
					table.insert( table_of_results, result )
				else
					local nearby_count = nearby_mats(index.pos_x, index.pos_y, "conway_life_mat")
					if nearby_count == 3 then
						local result = {index.pos_x, index.pos_y, nearby_count}
						table.insert( table_of_results, result )
					else
						table.remove( table_of_positions, i ) --remove empty spaces we've made for spreading, and can't spread to
					end
				end
			end
		end
	end
	
	for i, result_cell in ipairs(table_of_results) do
		--GamePrint(result_cell[1] .. ", " .. result_cell[2])
		if result_cell[3] > 4 then
			local pos_ptr = world_ffi.get_cell(chunk_map, result_cell[1], result_cell[2])
			if pos_ptr[0] ~= nil then
				local mat_id = CellFactory_GetName(world_ffi.get_material_id(pos_ptr[0].vtable.get_material(pos_ptr[0])))
				if mat_id == "conway_life_mat" then
					local pixel = world_ffi.remove_cell(grid_world, pos_ptr[0], result_cell[1], result_cell[2], true)
					pos_ptr[0] = pixel
				end
			end
		elseif result_cell[3] >= 3 then
			local pos_ptr = world_ffi.get_cell(chunk_map, result_cell[1], result_cell[2])
			if pos_ptr[0] == nil then
				local mat_ptr = world_ffi.get_material_ptr(CellFactory_GetType("conway_life_mat"))
				local pixel = world_ffi.construct_cell(grid_world, result_cell[1], result_cell[2], mat_ptr, nil)
				pos_ptr[0] = pixel
				local new_insert = {pos_x = result_cell[1], pos_y = result_cell[2]}
				--table.insert( table_of_positions, new_insert ) Note: Since this already exists it will update next frame.
				table_insert_9x9( result_cell[1], result_cell[2] ) -- Get new spaces to spread to
			end
		else
			local pos_ptr = world_ffi.get_cell(chunk_map, result_cell[1], result_cell[2])
			if pos_ptr[0] ~= nil then
				local mat_id = CellFactory_GetName(world_ffi.get_material_id(pos_ptr[0].vtable.get_material(pos_ptr[0])))
				if mat_id == "conway_life_mat" then
					local pixel = world_ffi.remove_cell(grid_world, pos_ptr[0], result_cell[1], result_cell[2], true)
					pos_ptr[0] = pixel
				end
			end
		end
	end
end


function OnPlayerSpawned(pid)
	local spawn_check = tonumber(GlobalsGetValue( "EXTOL_CONWAY_INIT", "0" ))
	if spawn_check == 0 then
		local x, y = EntityGetTransform(pid)
		EntityLoad( "mods/conway_mod/files/conway_wand.xml", x + 15, y + 10 )
		GlobalsSetValue( "EXTOL_CONWAY_INIT", "1" )
	end
end