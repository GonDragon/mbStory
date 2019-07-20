require "/scripts/util.lua"
require "/quests/scripts/questutil.lua"
require "/scripts/vec2.lua"
require "/quests/scripts/portraits.lua"

function init()
  storage.complete = storage.complete or false
  self.compassUpdate = config.getParameter("compassUpdate", 0.5)
  self.descriptions = config.getParameter("descriptions")

  self.scientistUid = config.getParameter("scientistUid")
  self.techstationUid = config.getParameter("techstationUid")

  self.findRange = config.getParameter("findRange")
  self.exploreTime = config.getParameter("exploreTime")
  storage.exploreTimer = storage.exploreTimer or 0

  setPortraits()

  storage.stage = storage.stage or 1
  self.stages = {
    explore,
    findScientist,
    scientistFound
  }

  self.state = FSM:new()
  self.state:set(self.stages[storage.stage])
end

function questInteract(entityId)
  if self.onInteract then
    return self.onInteract(entityId)
  end
end

function questStart()
  player.upgradeShip(config.getParameter("shipUpgrade"))
end

function update(dt)
  self.state:update(dt)

  if storage.complete then
    quest.setCanTurnIn(true)
  end
end

function explore()
  quest.setObjectiveList({{self.descriptions.explore, false}})

  -- Wait until the player is no longer on the ship
  local radioMessageSent = false
  local findSci = util.uniqueEntityTracker(self.scientistUid, self.compassUpdate)
  local buffer = 0
  while storage.exploreTimer < self.exploreTime do
    -- quest.setProgress(math.min(storage.exploreTimer / self.exploreTime, 1.0)) -- Debug
    buffer = buffer + script.updateDt()

    local sciPosition = findSci()
    if sciPosition then
      if not radioMessageSent then
        util.wait(1)
        player.radioMessage("mb-exploreTime")
        radioMessageSent = true
      end
      -- Mine is on this world, put buffer onto the exploration timer
      storage.exploreTimer = storage.exploreTimer + buffer
      buffer = 0
      if world.magnitude(mcontroller.position(), sciPosition) < self.findRange then
        storage.stage = 3
        self.state:set(self.stages[storage.stage])
        coroutine.yield()
      end
    elseif sciPosition == nil then
      -- Gate is not in this world, discard the buffer
      buffer = 0
    end
    coroutine.yield()
  end

  storage.stage = 2

  player.radioMessage("mb-findSci")

  util.wait(8)

  self.state:set(self.stages[storage.stage])
end

function findScientist()
  quest.setProgress(nil)
  quest.setObjectiveList({{self.descriptions.findScientist, false}})

  -- Wait until the player is no longer on the ship
  local findSci = util.uniqueEntityTracker(self.scientistUid, self.compassUpdate)
  while true do
    local result = findSci()
    questutil.pointCompassAt(result)
    if result and world.magnitude(mcontroller.position(), result) < self.findRange then
      self.state:set(scientistFound)
    end
    coroutine.yield()
  end

  self.state:set(self.stages[storage.stage])
end

function scientistFound()
  storage.stage = 3
  quest.setProgress(nil)
  quest.setCompassDirection(nil)
  quest.setObjectiveList({{self.descriptions.scientistFound, false}})
  player.radioMessage("mb-sciFound")
  storage.complete = true

  local findSci = util.uniqueEntityTracker(self.scientistUid, self.compassUpdate)
  while true do
    questutil.pointCompassAt(findSci())
    coroutine.yield()
  end
end

function questComplete()
  setPortraits()
  questutil.questCompleteActions()
end
