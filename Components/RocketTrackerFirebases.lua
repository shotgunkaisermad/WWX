local targetMarks = {}
local usingSmoke = true
local delayTime = 15
local smokeTracker = {}
local artyPoints = {
    [1] = {},
    [2] = {},
}
--idea, player launches rockets, whole burst is tracked, after set time, rocket positions are averaged and a strike hits the average point 
--event listener
local smokeEvents = {}
function smokeEvents:onEvent(event)
    if usingSmoke and event and event.id == world.event.S_EVENT_SHOT and event.initiator and event.initiator.getPlayerName then
        local playerName = event.initiator:getPlayerName()
        if playerName and event.weapon:getCategory() == 2 then
            if smokeTracker.isSmokeRocket(event.weapon:getDesc()["displayName"]) then
                if targetMarks[playerName] == nil or (targetMarks[playerName] and targetMarks[playerName].startTime and timer:getTime() - targetMarks[playerName].startTime >= delayTime) then
                    env.info("adding marks table for player: " .. playerName, false)
                    targetMarks[playerName] = {
                        tracking = true,
                        startTime = timer:getTime(),
                        points = {},
                    }
                    timer.scheduleFunction(smokeTracker.fire, {playerName = playerName, coalition = event.initiator:getCoalition()}, timer:getTime() + delayTime)
                end
                smokeTracker.trackWeapon({weapon = event.weapon, playerName = event.initiator:getPlayerName()})
            end
        end
    end
end
function smokeTracker.isSmokeRocket(weaponDesc)
    if string.find(weaponDesc, 'SM') or string.find(weaponDesc, 'TsM') or string.find(weaponDesc, 'SMK') or string.find(weaponDesc, 'Green') or string.find(weaponDesc, 'Red') or string.find(weaponDesc, 'Yellow') or string.find(weaponDesc, 'Wht Phos') then
        env.info("smoke rocket fired: " .. weaponDesc, false)
        return true
    end
    return false
end
--end event listener
--weapon, playerName
function smokeTracker.trackWeapon(param)
    if param.weapon:isExist() then
        local vec = param.weapon:getVelocity()
        local weaponSpeed = (vec.x^2 + vec.y^2 + vec.z^2)^0.5
        local smokePoint = land.getIP(param.weapon:getPosition().p, param.weapon:getPosition().x, weaponSpeed * 0.1)
        if smokePoint and targetMarks[param.playerName] then
            env.info("smoke rocket IP added to table for " .. param.playerName, false)
            table.insert(targetMarks[param.playerName].points, smokePoint)
        else
            timer.scheduleFunction(smokeTracker.trackWeapon, {weapon = param.weapon, playerName = param.playerName}, timer.getTime()+0.1)
        end
    end
end
--playerName, coalition
function smokeTracker.fire(param)
    env.info("smoke rocket fire for " .. param.playerName, false)
    if targetMarks[param.playerName] and targetMarks[param.playerName].points and #targetMarks[param.playerName].points > 0 then
        env.info("player table found and populated", false)
        local avgPoint = targetMarks[param.playerName].points[1]
        local pointCount = #targetMarks[param.playerName].points
        if pointCount > 1 then
            for i = 2, pointCount do
                local currentPoint = targetMarks[param.playerName].points[i]
                avgPoint.x = avgPoint.x + currentPoint.x
                avgPoint.y = avgPoint.y + currentPoint.y
                avgPoint.z = avgPoint.z + currentPoint.z
            end
            avgPoint.x = avgPoint.x / pointCount
            avgPoint.y = avgPoint.y / pointCount
            avgPoint.z = avgPoint.z / pointCount
        end
        --this point is where we want to blow up stuff, replace smoke with call to artillery fire function
        --trigger.action.smoke(avgPoint, 0)
        env.info("artillery point added for " .. param.playerName, false)
        table.insert(artyPoints[param.coalition], avgPoint)

    end
    targetMarks[param.playerName] = nil
end
function smokeTracker.assignmentLoop()
    for c = 1,2 do
        for i=1, #artyPoints[c] do
            env.info("Checking point: " .. c .. "-" .. i, false)
            local firedOn = Firebases.rocketFire(artyPoints[c][i], c)
            if firedOn then
                env.info("smoke rocket point fired on or out of range", false)
                table.remove(artyPoints[c], i)
                break
            end
        end
    end
    timer.scheduleFunction(smokeTracker.assignmentLoop, nil, timer:getTime() + 10)
end
world.addEventHandler(smokeEvents)
smokeTracker.assignmentLoop()