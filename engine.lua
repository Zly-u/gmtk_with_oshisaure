local Utils = require("utils")
local Tower = require("tower")
local Enemy = require("enemy")

local shoplist = {
    {name = "Stroller",   cost =    200, clicks = 1, key = "basic"},
    {name = "Patroller",  cost =   2000, clicks = 1, key = "patrol"},
    {name = "Sleeper",    cost =  10000, clicks = 1, key = "static"},
    {name = "Warper",     cost =  20000, clicks = 1, key = "teleporting"},
    {name = "Marcher",    cost =  50000, clicks = 2, key = "patrol2p"},
    {name = "Entangler",  cost = 120000, clicks = 4, key = "quantum"},
    {name = "Rain Maker", cost = 660000, clicks = 1, key = "little_goblin"},
}
for i = 1, #shoplist do shoplist[i].i = i end

local costscale = 1.05
local enemy_kinds = {
    {size = 10, hp = 100, speed = 10}, --normal
    {size =  6, hp =  40, speed = 25}, --small
    {size = 20, hp = 200, speed =  5}, --big
}
local paththickness = 30
local engine = {
    towers = {},
    enemies = {},
    bullets = {},
    path = {},
    money = 0,
    crossed = 0,
    oob_distance = 100,
    canvas = love.graphics.newCanvas(720,720),
    placing_tower = nil,
    tower_clicks = {},
    --[[
    difficulty = 0,
    wave_current_diff = 0,
    --]]
    next_enemy_in = 0,
    wave_count = 0,
    wave_enemies_left = 0,
    next_wave_in = 0,
    tower_counts = {},
    
    addTower = function(self, tower)
        table.insert(self.towers, tower)
    end,

    addEnemy = function(self, enemy)
        table.insert(self.enemies, enemy)
    end,
    
    setPath = function(self, points)
        self.path = points
    end,

    clearTowers = function(self)
        self.towers = {}
    end,
    
    clearEnemies = function(self)
        self.enemies = {}
    end,
    
    reset = function(self, path, startmoney)
        self:clearEnemies()
        self:clearTowers()
        self:setPath(path)
        self.money = startmoney
        self.crossed = 0
        --[[
        self.difficulty = 0
        self.wave_current_diff = 0
        ]]
        self.next_enemy_in = 0
        self.wave_count = 0
        self.next_wave_in = 3
        self.wave_enemies_left = 0
        for i = 1, #shoplist do
            self.tower_counts[i] = 0
        end
    end,
    
    update = function(self, dt)
        for _, enemy in pairs(self.enemies) do
            enemy:update(self.path, dt)
        end

        for _, _tower in pairs(self.towers) do
            local target = _tower:isInRadius(self.enemies)
            local bullet = _tower:update(target, dt)

            for _, tower in pairs(_tower.q_towers or {_tower}) do
                if bullet then table.insert(self.bullets, bullet) end
                for k = 2, #self.path do
                    local a_tower = {x = tower.actual_x, y = tower.actual_y}
                    local proj = Utils.closestPtOnLn(a_tower, self.path[k-1], self.path[k])
                    local dist = Utils.distanceOO(proj, a_tower)
                    while dist == 0 do
                        tower.actual_x = tower.actual_x + math.random()*0.2-0.1
                        tower.actual_y = tower.actual_y + math.random()*0.2-0.1
                        a_tower = {x = tower.actual_x, y = tower.actual_y}
                        proj = Utils.closestPtOnLn(a_tower, self.path[k-1], self.path[k])
                        dist = Utils.distanceOO(proj, a_tower)
                    end

                    if dist < paththickness then
                        local a_tower = {x = tower.actual_x, y = tower.actual_y}
                        local newpos = Utils.extendLine(proj, a_tower, paththickness)
                        tower.actual_x = newpos.x
                        tower.actual_y = newpos.y
                    end
                end
            end
        end
        
        local nextframe_bullets = {}
        for _, bullet in pairs(self.bullets) do
            bullet:update(dt)

            local target = nil
            local targetdist = bullet.size
            for _, enemy in pairs(self.enemies) do
                local d = Utils.distanceOO(enemy, bullet) - enemy.size
                if d <= targetdist then
                    target = enemy
                    targetdist = d
                end
            end
            if target then
                -- bullet:hit(target) later, for now just apply damage and stop keeping track of the bullet -- Lilla
                target.hp = target.hp - bullet.damage
            elseif bullet.x >   0 - self.oob_distance
            and    bullet.y >   0 - self.oob_distance
            and    bullet.x < 720 + self.oob_distance
            and    bullet.y < 720 + self.oob_distance
            then
                table.insert(nextframe_bullets, bullet)
            end
        end
        self.bullets = nextframe_bullets
        
        for k = #self.enemies, 1, -1 do
            local enemy = self.enemies[k]
            if enemy.hp < 0 then
                table.remove(self.enemies, k)
                self.money = self.money + enemy.money
            elseif enemy.reachedEnd then
                table.remove(self.enemies, k)
                self.crossed = self.crossed + 1
            end
        end
        
        
        -- enemy spawn
        --[[
        self.difficulty = self.difficulty + dt
        if self.next_wave_in > 0 then
            self.next_wave_in = self.next_wave_in - dt
            if self.next_wave_in <= 0 then
                self.wave_current_diff = self.difficulty
            end
        else
            if self.next_enemy_in > 0 then
                self.next_enemy_in = self.next_enemy_in - dt
            else
                local e = enemy_kinds[math.random(math.min(math.floor(self.difficulty/10 + 1), #enemy_kinds))]
                local diffmult = math.max(self.wave_current_diff, self.difficulty * 1.2 * math.random())*0.1
                local x, y = unpack(self.path[1])
                self:addEnemy(Enemy.new(x, y, e.size, e.speed, math.tau*math.random(), e.hp*diffmult, "basic"))
                self.wave_current_diff = self.wave_current_diff - diffmult*10
                print(self.wave_current_diff, diffmult)
                if self.wave_current_diff > 0 then
                    self.next_enemy_in = math.random()*0.5
                else
                    self.next_wave_in = 20+math.random(40)
                end
            end
        end
        ]]
        
        --enemy spawn attempt 2
        if self.next_wave_in > 0 then
            self.next_wave_in = self.next_wave_in - dt
            if self.next_wave_in <= 0 then
                self.wave_count = self.wave_count + 1
                self.wave_enemies_left = self.wave_count
            end
        else
            if self.next_enemy_in > 0 then
                self.next_enemy_in = self.next_enemy_in - dt
            else
                local e = enemy_kinds[math.random(math.min(math.floor(self.wave_count/5 + 1), #enemy_kinds))]
                local x, y = unpack(self.path[1])
                self:addEnemy(Enemy.new(x, y, e.size, e.speed, Utils.angleBetweenXYXY(x,  y, self.path[2][1], self.path[2][2]), e.hp, "basic"))
                self.wave_enemies_left = self.wave_enemies_left - 1
                if self.wave_enemies_left > 0 then
                    self.next_enemy_in = math.random()*0.4+0.1
                else
                    self.next_wave_in = 45
                end
            end
        end
            
    end,

    draw = function(self)
        love.graphics.setCanvas(self.canvas) do
            love.graphics.setColor(0,0,0,0)
            love.graphics.clear()
            love.graphics.setColor(Utils.HSVA(100, 0.5, 0.7))
            love.graphics.rectangle("fill", 0,0,720,720)
            
            --Path preview
            local line = {}
            local line_dip = {}
            for _, point in ipairs(self.path) do
                table.insert(line, point[1])
                table.insert(line, point[2])
                table.insert(line_dip, point[1])
                table.insert(line_dip, point[2])
            end
            love.graphics.setColor(Utils.HSVA(60, 0.7, 0.8, 1))
            love.graphics.setLineWidth(2*paththickness)
            love.graphics.line(line)
            love.graphics.setColor(Utils.HSVA(45, 0.9, 0.7, 1))
            love.graphics.setLineWidth(paththickness)
            love.graphics.line(line_dip)
            love.graphics.setLineWidth(1)

            --Drawing entities
            love.graphics.setColor(1,1,1,1)
            love.graphics.rectangle("line", 1,0, 719,719)
            for _, tower  in pairs(self.towers ) do tower :draw() end
            for _, enemy  in pairs(self.enemies) do enemy :draw() end
            for _, bullet in pairs(self.bullets) do bullet:draw() end

        end love.graphics.setCanvas()

        --oooooo GUI Related
        love.graphics.setColor(Utils.HSVA(60, 0.7, 0.8, 1))
        love.graphics.print(string.format("Current funds: ¤%s", Utils.commaValue(Utils.truncate(self.money, -2))), 750, 30)
        love.graphics.setColor(Utils.HSVA(0, 0.7, 0.8, 1))
        love.graphics.print(string.format("Wave #%d", self.wave_count), 750, 15)
        if self.next_wave_in > 0 then
            love.graphics.print(string.format("Next wave in %d\"", self.next_wave_in), 900, 10)
        end

        for k, entry in ipairs(shoplist) do
            local currentcost = entry.cost*costscale^self.tower_counts[k]
            local canbuy = currentcost < self.money
            love.graphics.setColor(Utils.HSVA(k*30, canbuy and 1 or 0, 0.1))
            love.graphics.rectangle("fill", 720, 50*k, 560, 49)
            love.graphics.setColor(Utils.HSVA(k*30, canbuy and 1 or 0, canbuy and 1 or 0.7))
            love.graphics.rectangle("line", 720, 50*k, 560, 49)
            local cost = Utils.commaValue(Utils.truncate(currentcost, -2))
            love.graphics.print(string.format("%s: ¤%s", entry.name, cost), 750, 20+50*k)
        end

        --Draw shits ooooooo
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.canvas)
        
        if self.placing_tower then
            love.graphics.setColor(Utils.HSVA(self.placing_tower.i*30))
            for _, pt in ipairs(self.tower_clicks) do
            love.graphics.circle("line", pt.x, pt.y, 5)
            end
        end
        local mx, my = love.mouse.getPosition()
        love.graphics.line(mx-10, my-10, mx+10, my+10)
        love.graphics.line(mx-10, my+10, mx+10, my-10)
        love.graphics.circle("line", mx, my, 10)
    end,
    
    mousepressed = function(self, x, y, button, istouch, presses)
        if button == 1 then 
            if x >= 720 and not self.placing_tower then
                local item = shoplist[math.floor(y/50)]
                local currentcost = item and item.cost*costscale^self.tower_counts[item.i]
                if item and self.money >= currentcost then
                    self.money = self.money - currentcost
                    self.tower_clicks = {}
                    self.placing_tower = item
                end
            elseif x < 720 and self.placing_tower then
                table.insert(self.tower_clicks, {x = x, y = y})
                if #self.tower_clicks == self.placing_tower.clicks then
                    local pos = table.remove(self.tower_clicks, 1)
                    self:addTower(Tower.new(pos.x, pos.y, self.placing_tower.key, self.tower_clicks))
                    self.tower_counts[self.placing_tower.i] = self.tower_counts[self.placing_tower.i] + 1
                    self.placing_tower = nil
                end
            end
        end
    end
}

return engine