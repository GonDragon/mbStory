require "/scripts/util.lua"
require "/quests/scripts/questutil.lua"
require "/scripts/vec2.lua"
require "/quests/scripts/portraits.lua"

function init()
  self.compassUpdate = config.getParameter("compassUpdate", 0.5)
  self.descriptions = config.getParameter("descriptions")

  self.scientistUid = config.getParameter("scientistUid")
  self.repairItems = config.getParameter("repairItems")
  self.noticeRange = config.getParameter("noticeRange")

  quest.setParameter("itemList", config.getParameter("repairItemsIndicators"))

  setPortraits()

  storage.stage = storage.stage or 1
  self.stages = {
    collectRepairItem,
    returnToScientist
  }

  self.informated = self.informated or false

  self.state = FSM:new()
  self.state:set(self.stages[storage.stage])
end

function questInteract(entityId)
  if self.onInteract then
    return self.onInteract(entityId)
  end
end

function questStart()

end

function update(dt)
  self.state:update(dt)
end

function collectRepairItem()
  quest.setCompassDirection(nil)
  quest.setIndicators({"itemList"})
  local findSci = util.uniqueEntityTracker(self.scientistUid, self.compassUpdate)

  while storage.stage == 1 do
    local sciPosition = findSci()
    if sciPosition then
      if not self.informated and world.magnitude(mcontroller.position(), sciPosition) > self.noticeRange then
        player.radioMessage("gaterepair-gateFound2")
        player.radioMessage("mb-collectRepairItem1")
        player.radioMessage("mb-collectRepairItem2")
        self.informated = true
      end
    end

    quest.setObjectiveList({{self.descriptions.collectRepairItem, false}})
    local playerProgress = playerProgression(self.repairItems)
    quest.setProgress(playerProgress)
    if playerProgress == 1 then
      storage.stage = 2
      self.state:set(self.stages[storage.stage])
    end
    coroutine.yield()
  end

  quest.setObjectiveList({})
  self.state:set(self.stages[storage.stage])
end

function returnToScientist()
  quest.setProgress(nil)
  quest.setObjectiveList({{self.descriptions.returnToScientist, false}})
  quest.setCanTurnIn(true)
  quest.setIndicators({})

  local findSci = util.uniqueEntityTracker(self.scientistUid, self.compassUpdate)
  while storage.stage == 2 do
    if playerProgression(self.repairItems) ~= 1 then
      quest.setCanTurnIn(false)
      storage.stage = 1
      self.state:set(self.stages[storage.stage])
    end
    questutil.pointCompassAt(findSci())
    coroutine.yield()
  end

end

function playerProgression(itemMap)
  local playerItems = 0
  local itemsNeeded = 0
  for item, amount in pairs(itemMap) do
    playerItems = playerItems + math.min(player.hasCountOfItem(item),amount)
    itemsNeeded = itemsNeeded + amount
  end
  return playerItems / itemsNeeded
end

function questComplete()
  setPortraits()
  for item, amount in pairs(self.repairItems) do
    player.consumeItem({ name = item, count = amount })
  end
  player.upgradeShip(config.getParameter("shipUpgrade"))
  questutil.questCompleteActions()
end
