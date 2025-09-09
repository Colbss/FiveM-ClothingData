
local CLOTHING_DATA = {
    male   = { drawables = nil, props = nil },
    female = { drawables = nil, props = nil },
}
local DATA_READY = false

-- ---------- utils ----------

local VALID_GENDERS = { m = 'male', male = 'male', f = 'female', female = 'female' }
local VALID_TYPES   = { drawables = true, props = true }

local function strkey(k) return type(k) == 'number' and tostring(k) or k end

local function fetch(tbl, key, label, path)
    if tbl == nil then
        return nil, ('Missing table at %s'):format(path or '?')
    end
    local v = tbl[key]
    if v == nil then
        return nil, ('Invalid %s "%s" (path: %s)'):format(label or 'key', tostring(key), path or '?')
    end
    return v
end

-- ---------- JSON load ----------

local function LoadJsonFile(relPath)
    local raw = LoadResourceFile(GetCurrentResourceName(), relPath)
    if not raw then
        return nil, ('File not found: %s (does the file exist ?)'):format(relPath)
    end
    local ok, decoded = pcall(json.decode, raw)
    if not ok then
        return nil, ('JSON parse error in %s: %s'):format(relPath, tostring(decoded))
    end
    if type(decoded) ~= 'table' then
        return nil, ('Top-level JSON in %s must be an object/table'):format(relPath)
    end
    return decoded, nil
end

local function LoadAllClothingData()
    local maleDrawables, e1 = LoadJsonFile('data/male_drawables.json')
    if not maleDrawables then return false, e1 end

    local maleProps, e2 = LoadJsonFile('data/male_props.json')
    if not maleProps then return false, e2 end

    local femaleDrawables, e3 = LoadJsonFile('data/female_drawables.json')
    if not femaleDrawables then return false, e3 end

    local femaleProps, e4 = LoadJsonFile('data/female_props.json')
    if not femaleProps then return false, e4 end

    CLOTHING_DATA.male.drawables   = maleDrawables
    CLOTHING_DATA.male.props       = maleProps
    CLOTHING_DATA.female.drawables = femaleDrawables
    CLOTHING_DATA.female.props     = femaleProps

    return true, nil
end

CreateThread(function()
    local ok, err = LoadAllClothingData()
    if not ok then
        print(('[clothing] Load failed: %s'):format(err))
        DATA_READY = false
        return
    end
    DATA_READY = true
    TriggerEvent('clothingdata:ready')
end)

local function WaitForClothingData(maxMs)
    local deadline = GetGameTimer() + (maxMs or 5000)
    while not DATA_READY and GetGameTimer() < deadline do
        Wait(50)
    end
    return DATA_READY
end

-- ---------- Query API ----------

--- Returns: item, textureOrNil, errOrNil
local function GetClothingData(gender, clothType, collection, compType, index, texture)
    if not DATA_READY then
        return nil, nil, 'Clothing data not loaded yet'
    end

    local g = VALID_GENDERS[tostring(gender):lower()]
    if not g then return nil, nil, 'Invalid gender (expected "m"/"f")' end
    if not VALID_TYPES[clothType] then return nil, nil, 'Invalid clothing type (expected "drawables"/"props")' end

    local root = CLOTHING_DATA[g]
    if not root then return nil, nil, ('No clothing data for gender "%s"'):format(g) end

    local set = root[clothType]
    if not set then return nil, nil, ('No data for type "%s" under gender "%s"'):format(clothType, g) end
    local path = ('%s.%s'):format(g, clothType)

    local coll, err = fetch(set, collection, 'collection', path)
    if not coll then return nil, nil, err end
    path = path .. '.' .. collection

    local comp; comp, err = fetch(coll, compType, 'component', path)
    if not comp then return nil, nil, err end
    path = path .. '.' .. compType

    local idxKey = strkey(index)
    local item; item, err = fetch(comp, idxKey, 'index', path)
    if not item then return nil, nil, err end
    path = path .. '.' .. idxKey

    if texture == nil then
        return item, nil, nil
    end

    local texTable = item.textures
    if type(texTable) ~= 'table' then
        return item, nil, ('Missing "textures" at %s'):format(path)
    end

    local texKey = strkey(texture)
    local tex = texTable[texKey]
    if tex == nil then
        return item, nil, ('Invalid texture "%s" (path: %s.textures)'):format(texKey, path)
    end

    return item, tex, nil
end

-- Optional tiny helper
local function GetTextureLabel(gender, clothType, collection, compType, index, texture)
    local item, tex, err = GetClothingData(gender, clothType, collection, compType, index, texture)
    if not item then return nil, err end
    if not tex  then return nil, 'texture not found' end
    return tex.label
end

-- ---------- Example command ----------
RegisterCommand('getClothingData', function()
    if not WaitForClothingData(5000) then
        print('[clothing] Data not ready.')
        return
    end

    -- Example: read item-level properties and a texture
    local item, tex, err = GetClothingData('m', 'drawables', '', 'JBIB', 6, 0)
	if not item then
		print('Error 1:', err)
	else
		if tex then
			print('label:', tostring(tex.label))
		else
			print('No texture found:', err or 'nil')
		end
	end

    -- Example: check for special property
    local item, _, err = GetClothingData('m', 'drawables', 'Male_Heist', 'UPPR', 0)
	if not item then
		print('Error 2:', err)
	else
		print('Has Gloves ?', tostring(item.hasGloves))
	end
end)
