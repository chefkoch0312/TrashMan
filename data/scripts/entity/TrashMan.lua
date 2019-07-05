package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("utility")
include ("callable")
local SellableInventoryItem = include ("sellableinventoryitem")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TrashMan
TrashMan = {}

local systemsBox
local checkBoxes = {}
local listBoxes = {}
local grey = ColorRGB(.3,.3,.3)

local function addLine(matType, px, py, tooltip)
    local material = Material(matType)
    checkBoxes[matType] = window:createCheckBox(Rect(px, py, px + 20, py + 20), "", "")
    local label = window:createLabel(vec2(px + 25, py),  material.name, 15)
    label.color = material.color

    listBoxes[matType] = window:createComboBox(Rect(px + 150, py, px + 300, py + 20), "")
    for rType = RarityType.Petty, RarityType.Legendary do
        local rarity = Rarity(rType)
        listBoxes[matType]:addEntry(rarity.name)
    end
end

function TrashMan.getIcon()
    return "data/textures/icons/trash-can.png"
end

function TrashMan.interactionPossible(playerIndex, option)
    local self = Entity()
    local player = Player(playerIndex)

    local craft = player.craft
    if craft == nil then return false end

    -- Trash Man is accessible only when player is in the entity
    if craft.index == self.index then
        return true
    end

    return false
end

-- this function gets called on creation of the entity the script is attached to, on client only
-- AFTER initialize above
-- create all required UI elements for the client side
function TrashMan.initUI()
    local res = getResolution();
    local size = vec2(350, 390) 
    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5));
    menu:registerWindow(window, "Trash Man"%_t);

    window.caption = "Trash Man"%_t
    window.showCloseButton = 1
    window.moveable = 1
    window.clickThrough = 0

    local hsplit = UIHorizontalSplitter(Rect(vec2(), size), 10, 10, 0.5)
    hsplit.bottomSize = 30
    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)

    local column1 = 10
    local column2 = 30
    local py = 10
    local lineHeight = 20
    local pyDelta = 30

    -- Systems To Trash
    window:createLabel(vec2(column1, py),  "Systems to trash"%_t, 15)
    py = py + pyDelta
    systemsBox = window:createComboBox(Rect(column2, py, column2 + 300, py + lineHeight), "")
    systemsBox:addEntry("None"%_t)
    for rType = RarityType.Petty, RarityType.Legendary do
        local rarity = Rarity(rType)
        systemsBox:addEntry(rarity.name)
    end
    py = py + pyDelta
	
    -- Turrets to Trash
    window:createLabel(vec2(column1, py),  "Turrets to trash"%_t, 15)
    py = py + pyDelta

    for materialNumber = MaterialType.Iron, MaterialType.Avorion do
        addLine(materialNumber, column2, py)
        py = py + pyDelta
    end

    local qFrame = window:createFrame(Rect(310, 10, 330, 30))
    local qLabel = window:createLabel(vec2(310, 10), " ?", 15)

    --qFrame.position = vec2(260, 10)
    --qLabel.position = qFrame.position
    qLabel.tooltip = "Select which types of inventory items to mark as trash. These items will not be destroyed or immediately sold. Instead, the next time you visit the appropriate merchant they can be sold with the merchant's 'Sell Trash' button.\nItems that are marked as favorites will not get marked for trash!"%_t

    local button1 = window:createButton(vsplit.left, "Mark Selected"%_t, "onMarkTrashPressed")
    local button2 = window:createButton(vsplit.right, "Unmark All"%_t, "onUnmarkAllPressed")
    button1.maxTextSize = 15
    button2.maxTextSize = 15
end

function TrashMan.onMarkTrashPressedServer(systemRarity, turretRarities)
    if onClient() then return end

    local itemsMarked = 0
    local inv = Player(callingPlayer):getInventory()
    
    for index, slotItem in pairs(inv:getItems()) do
        local iitem = slotItem.item
        if ((iitem == nil) or iitem.trash or iitem.favorite) then goto continue end

        local sItem = SellableInventoryItem(iitem, index, buyer)
        if (sItem.item.itemType == InventoryItemType.VanillaItem) then goto continue end		
        local rarity = sItem.rarity.value
		
        if (sItem.item.itemType == InventoryItemType.SystemUpgrade) then 
            if rarity > systemRarity then goto continue end
            -- print("Trashing " .. sItem.rarity.name .. " " ..sItem:getName())
            iitem.trash = true
            local amount = inv:amount(index)
            inv:removeAll(index)
            inv:addAt(iitem, index, amount)				
            itemsMarked = itemsMarked + amount	
        else 
            local material = sItem.material.value
            if (turretRarities[material]) then
                local selectedMaxRarity = turretRarities[material]
                if (rarity <= turretRarities[material]) then	
                    local name = sItem.rarity.name .. " " .. Material(sItem:getMaterial()).name .. " " ..sItem:getName()
                    --print("Trashing " .. name)
                    iitem.trash = true
                    local amount = inv:amount(index)
                    inv:removeAll(index)
                    inv:addAt(iitem, index, amount)				
                    itemsMarked = itemsMarked + amount
                end
            end
        end

        ::continue::
    end

    Player(callingPlayer):sendChatMessage("Server", 0, itemsMarked .. " items have been marked as trash.")
end
callable(TrashMan, "onMarkTrashPressedServer")

function TrashMan.onUnmarkAllPressedServer()
    if onClient() then return end

    local itemsMarked = 0
    local inv = Player(callingPlayer):getInventory()
    local totalItems = 0
	
    for index, slotItem in pairs(inv:getItems()) do
        local iitem = slotItem.item
        if (iitem ~= nil) then
            local amount = inv:amount(index)
            local iitem = slotItem.item
            
            totalItems = totalItems + amount

            if (iitem.trash) then
                local sItem = SellableInventoryItem(iitem, index, buyer)
                local name = Rarity(sItem.rarity.value).name .. " " .. Material(sItem:getMaterial()).name .. " " ..sItem:getName()
                name = name .. "(" .. iitem.itemType .. ")"

                -- print("Untrashing " .. name)
                iitem.trash = false
                
                inv:removeAll(index)
                inv:addAt(iitem, index, amount)				
                itemsMarked = itemsMarked + amount
            end
        end
    end

    Player(callingPlayer):sendChatMessage("Server", 0, itemsMarked .. " of " .. totalItems .. " items are no longer marked for trash.")
end
callable(TrashMan, "onUnmarkAllPressedServer")

function TrashMan.onMarkTrashPressed()
    local turretRarities = {}
    
    for mat = MaterialType.Iron, MaterialType.Avorion do
        if (checkBoxes[mat].checked) then
            turretRarities[mat] = listBoxes[mat].selectedIndex - 1
        end
    end

    invokeServerFunction("onMarkTrashPressedServer", (systemsBox.selectedIndex - 2), turretRarities)
    window:hide()
end

function TrashMan.onUnmarkAllPressed()
    invokeServerFunction("onUnmarkAllPressedServer")
    window:hide()
end