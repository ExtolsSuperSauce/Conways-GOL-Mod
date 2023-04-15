ModMaterialsFileAdd("mods/conway_mod/files/mat.xml")
dofile_once("mods/conway_mod/nsew/load.lua")("mods/conway_mod")

local ffi = require 'ffi'
local world_ffi = require("nsew.world_ffi")

local life_templates = {
	["Glider Gun"] = [[
                        O
                      O O
            OO      OO            OO
           O   O    OO            OO
OO        O     O   OO
OO        O   O OO    O O
          O     O       O
           O   O
            OO
]]
}

local function nearby_mats( matx, maty, mat_name )
	local search_result = 0
	local search_count = 0
	local offset_y = math.floor(maty) - 1
	local grid_world = world_ffi.get_grid_world()
	local chunk_map = grid_world.vtable.get_chunk_map(grid_world)
	while search_count < 9 do
		local offset_x = math.floor(matx) + ((search_count % 3) - 1)
		if not (offset_x == matx and offset_y == maty) then
			local pcell = world_ffi.get_cell(chunk_map, offset_x, offset_y)
			if pcell[0] ~= nil then
				local mat_id = CellFactory_GetName(world_ffi.get_material_id(pcell[0].vtable.get_material(pcell[0])))
				if mat_id == mat_name then search_result = search_result + 1 end
			end
		end
		if search_count % 3 == 2 then offset_y = offset_y + 1 end
		search_count = search_count + 1
	end
	return search_result
end

local function table_insert_3x3( mid_x, mid_y )
	local x_off_list = {-1, -1, -1, 0, 0, 0, 1, 1, 1 }
	local y_off_list = {-1, 0, 1, -1, 0, 1, -1, 0, 1}
	for i=1, 9, 1 do
		local has_found = false
		local position_insert = { pos_x = mid_x + x_off_list[i], pos_y = mid_y + y_off_list[i]}
		for i, pos_ind in ipairs(table_of_positions) do
			if pos_ind.pos_x == position_insert.pos_x and pos_ind.pos_y == position_insert.pos_y then
				has_found = true
				break
			end
		end
		if not has_found then
			table.insert(table_of_positions, position_insert)
		end
	end
end

local function PlaceTemplate(template, start_x, start_y)
	local x = start_x
	local y = start_y

	for idx=1, #template do
		local chr = template:sub(idx, idx)
		if chr == '\n' then
			x = start_x
			y = y + 1
		elseif chr == 'O' then
			local grid_world = world_ffi.get_grid_world()
			local chunk_map = grid_world.vtable.get_chunk_map(grid_world)
			local pos_ptr = world_ffi.get_cell(chunk_map, x, y)
			if pos_ptr[0] == nil then
				local mat_ptr = world_ffi.get_material_ptr(CellFactory_GetType("conway_life_mat"))
				local pixel = world_ffi.construct_cell(grid_world, x, y, mat_ptr, pos_ptr[0])
				pos_ptr[0] = pixel
				table_insert_3x3( x, y )
			end
			GamePrint("Placement")
			x = x + 1
		else
			x = x + 1
		end
	end
end

-- GUI STUFF 
-- MY RANDOM NUMBER. NOT YOURS
local new_id
gui = gui or GuiCreate()
table_of_positions = table_of_positions or {}

local function get_new_id()
	new_id = new_id + 1
	return new_id
end 

local function gui_image_button( guix, guiy, image, text )
	GuiImageButton( gui, get_new_id(), guix, guiy, text, image )
	local isclicked, rclicked, ishovered = GuiGetPreviousWidgetInfo( gui )
	return isclicked, ishovered, rclicked
end

local function gui_button( guix, guiy, text )
	GuiButton( gui, get_new_id(), guix, guiy, text )
	local isclicked, rclicked, ishovered = GuiGetPreviousWidgetInfo( gui )
	return isclicked, ishovered, rclicked
end


function OnWorldPostUpdate()
	
	local player = EntityGetWithName("DEBUG_NAME:player")
	local i2c_id = EntityGetFirstComponentIncludingDisabled( player, "Inventory2Component")
	local item_id = ComponentGetValue2( i2c_id, "mActiveItem" )
	
	local cc_id = EntityGetFirstComponentIncludingDisabled( player, "ControlsComponent" )
	local ml_down = ComponentGetValue2( cc_id, "mButtonDownLeftClick" )
	local mr_down = ComponentGetValue2( cc_id, "mButtonDownRightClick" )
	local should_simulate = GlobalsGetValue( "Conway_Extol_Sim", "false" ) == "true"
	local grid_world = world_ffi.get_grid_world()
	local chunk_map = grid_world.vtable.get_chunk_map(grid_world)
	if EntityGetName(item_id) == "CONWAY_STONE" then
		local x, y = DEBUG_GetMouseWorld()
		x = math.floor(x)
		y = math.floor(y)
		if ComponentGetValue2(cc_id, "mButtonFrameKick") == GameGetFrameNum() then
			should_simulate = not should_simulate
			GlobalsSetValue("Conway_Extol_Sim", tostring(should_simulate))
		end
		
		--only display the GUI while stone is held
		--TODO: ghost sprite, GUI Images? 
		--GameCreateSpriteForXFrames( file, x, y, centered, offset_x, offset_y, frame, false)
		new_id = 577064850
		local screen_x, screen_y = GuiGetScreenDimensions(gui)
		open_gui = open_gui or false
		local clicked, hovered = gui_image_button( 101, 45, "mods/conway_mod/files/not_waterstone_ui.png", "" )
		if clicked then
			open_gui = not open_gui
		end
		
		slct_template = slct_template or nil
		if open_gui then
			GuiText( gui, screen_x/2 - 150, screen_y/2 - 180, "Templates" )
			local button_offset_x = screen_x/2 - 145
			local button_offset_y = screen_y/2 - 170
			for i in pairs(life_templates) do
				clicked, hovered = gui_button( button_offset_x, button_offset_y, i )
				if clicked then
					if slct_template == i then
						slct_template = nil
					else
						slct_template = i
					end
					GamePrint("Template: " .. tostring(slct_template))
				end
				button_offset_y = button_offset_y - 10
				if button_offset_y < 70 then
					button_offset_y = screen_y/2 - 170
					button_offset_x = button_offset_x - 100
				end
			end
		end
		GuiStartFrame(gui)
		
		
		local cursor_check = world_ffi.chunk_loaded(chunk_map,x,y)
		if ml_down and not should_simulate and cursor_check and not hovered then
			if slct_template == nil then
				local pos_ptr = world_ffi.get_cell(chunk_map, x, y)
				if pos_ptr[0] == nil then -- check for template
					local mat_ptr = world_ffi.get_material_ptr(CellFactory_GetType("conway_life_mat"))
					local pixel = world_ffi.construct_cell(grid_world, x, y, mat_ptr, pos_ptr[0])
					pos_ptr[0] = pixel
					table_insert_3x3( x, y )
					GamePrint("Placed")
				end
			else
				PlaceTemplate(life_templates[slct_template], x, y)
			end
		elseif mr_down and cursor_check and not hovered then
			local pos_ptr = world_ffi.get_cell(chunk_map, x, y)
			if pos_ptr[0] ~= nil then
				local mat_id = CellFactory_GetName(world_ffi.get_material_id(pos_ptr[0].vtable.get_material(pos_ptr[0])))
				if mat_id == "conway_life_mat" then
					local pixel = world_ffi.remove_cell(grid_world, pos_ptr[0], x, y, true)
					pos_ptr[0] = pixel
					table_insert_3x3( x, y )
				end
			end
		end
	else
		open_gui = false
	end

	if not should_simulate or GameGetFrameNum() % 5 ~= 0 then
		return
	end
	
	if #table_of_positions < 1 then
		GlobalsSetValue( "Conway_Extol_Sim", "0" )
		return
	end
	
    local table_of_results = {}
    for i, position in ipairs(table_of_positions) do
        local nearby_count = nearby_mats(position.pos_x, position.pos_y, "conway_life_mat")
        local result = {position.pos_x, position.pos_y, nearby_count}
        table.insert(table_of_results, result)
    end
	
    table_of_positions = {}
	
	for i, result_cell in ipairs(table_of_results) do
		if result_cell[3] > 3 then
			local pos_ptr = world_ffi.get_cell(chunk_map, result_cell[1], result_cell[2])
			if pos_ptr[0] ~= nil then
				local mat_id = CellFactory_GetName(world_ffi.get_material_id(pos_ptr[0].vtable.get_material(pos_ptr[0])))
				if mat_id == "conway_life_mat" then
					local pixel = world_ffi.remove_cell(grid_world, pos_ptr[0], result_cell[1], result_cell[2], true)
					pos_ptr[0] = pixel
				end
			end
			table_insert_3x3( result_cell[1], result_cell[2] )
		elseif result_cell[3] >= 2 then
			local pos_ptr = world_ffi.get_cell(chunk_map, result_cell[1], result_cell[2])
			if pos_ptr[0] == nil and result_cell[3] == 3 then
				local mat_ptr = world_ffi.get_material_ptr(CellFactory_GetType("conway_life_mat"))
				local pixel = world_ffi.construct_cell(grid_world, result_cell[1], result_cell[2], mat_ptr, nil)
				pos_ptr[0] = pixel
			end
			table_insert_3x3( result_cell[1], result_cell[2] )
		else
			local pos_ptr = world_ffi.get_cell(chunk_map, result_cell[1], result_cell[2])
			if pos_ptr[0] ~= nil then
				local mat_id = CellFactory_GetName(world_ffi.get_material_id(pos_ptr[0].vtable.get_material(pos_ptr[0])))
				if mat_id == "conway_life_mat" then
					local pixel = world_ffi.remove_cell(grid_world, pos_ptr[0], result_cell[1], result_cell[2], true)
					pos_ptr[0] = pixel
					table_insert_3x3( result_cell[1], result_cell[2] )
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