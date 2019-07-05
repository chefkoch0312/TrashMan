if onServer() then
    local entity = Entity()
    if (entity.isDrone or entity.isShip or entity.isStation) and not entity.aiOwned then
        entity:addScriptOnce("data/scripts/entity/TrashMan.lua")
    end
end