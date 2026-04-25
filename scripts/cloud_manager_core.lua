-- ============================================================================
-- cloud_manager_core.lua - 三国武灵录 (从 cloud_manager.lua 拆分)
-- 核心存储: Init, CollectDomainData, SaveAll, SaveDomain, LoadAll
-- ============================================================================
---@diagnostic disable: undefined-global

CloudManager = {}

-- ============================================================================
-- 甯搁噺 & 閰嶇疆
-- ============================================================================
local PREFIX = "p_49dd_"

-- 个人存档 domain 定义
local DOMAINS = {
    core     = PREFIX .. "sv_core",
    heroes   = PREFIX .. "sv_heroes",
    equip    = PREFIX .. "sv_equip",
    skills   = PREFIX .. "sv_skills",
    progress = PREFIX .. "sv_progress",
    welfare  = PREFIX .. "sv_welfare",
    social   = PREFIX .. "sv_social",
    explore  = PREFIX .. "sv_explore",
    worldmap = PREFIX .. "sv_worldmap",
}

-- 公开/社交 key
local KEYS = {
    combat_power  = PREFIX .. "combat_power",
    pub_profile   = PREFIX .. "pub_profile",
    realm_level   = PREFIX .. "realm_level",
    -- 好友公共申请池 (排行榜模拟公共信箱)
    freq_outbox_ts = PREFIX .. "freq_outbox_ts",  -- SetInt: 最新申请时间戳 (排行用)
    freq_outbox    = PREFIX .. "freq_outbox",      -- Set: 出站申请列表 JSON
    freq_resp_ts   = PREFIX .. "freq_resp_ts",     -- SetInt: 最新回复时间戳
    freq_resp      = PREFIX .. "freq_resp",        -- Set: 回复列表 JSON
    -- 阵营公共存储 (排行榜模拟阵营总表)
    camp_leader_ts = PREFIX .. "camp_leader_ts",   -- SetInt: 阵营创建时间 (排行用, 仅盟主)
    camp_meta      = PREFIX .. "camp_meta",        -- Set: 阵营元数据 (仅盟主维护)
    camp_apply_ts  = PREFIX .. "camp_apply_ts",    -- SetInt: 入营申请时间
    camp_apply     = PREFIX .. "camp_apply",       -- Set: 入营申请 JSON
    camp_resp_ts   = PREFIX .. "camp_resp_ts",     -- SetInt: 盟主审批回复时间
    camp_resp      = PREFIX .. "camp_resp",        -- Set: 审批回复 JSON
    -- 阵营聊天 (每人发布自己的最近消息, 轮询合并)
    camp_chat_ts   = PREFIX .. "camp_chat_ts",      -- SetInt: 最新聊天时间戳 (排行用)
    camp_chat      = PREFIX .. "camp_chat",          -- Set: 最近消息列表 JSON [{text,time,ts}]
    world_chat_ts  = PREFIX .. "world_chat_ts",      -- SetInt: 世界聊天时间戳 (排行用)
    world_chat     = PREFIX .. "world_chat",          -- Set: 世界聊天消息列表
    -- 封禁系统 (开发者通过排行榜发布封禁名单)
    ban_ts        = PREFIX .. "ban_ts",            -- SetInt: 封禁发布时间
    ban_data      = PREFIX .. "ban_data",           -- Set: 封禁名单 JSON
    -- 存档校验
    save_hash     = PREFIX .. "save_hash",          -- Set: 存档哈希校验值
    -- 兼容旧存档
    legacy_save   = PREFIX .. "savegame",
    -- 好友公共申请池 (排行榜模拟公共信箱)
    mail_ts       = PREFIX .. "mail_ts",           -- SetInt: 最新发件时间戳 (排行用)
    mail_outbox   = PREFIX .. "mail_outbox",       -- Set: 发件箱 JSON [{to,subject,body,rewards,time,id}]
}

local MAX_FRIENDS = 50
local REQUEST_EXPIRE_SECONDS = 7 * 86400  -- 申请7天过期
local MAX_OUTBOX = 20       -- 每人最多20条待处理出站申请
local MAX_CAMP_MEMBERS = 20 -- 阵营最大人数（1级阵营上限）
local CAMP_CREATE_COST = 5000 -- 创建阵营消耗玉壁
local SAVE_VERSION = 2  -- 存档版本 (1=旧单key, 2=新多domain)

-- ============================================================================
-- 阵营职位体系 (仿率土之滨同盟)
-- 继承链: leader → vice_leader → strategist → vanguard → diplomat → elite → member
-- ============================================================================
local FACTION_ROLES = {
    leader      = { level = 6, name = "盟主",   max = 1  },
    vice_leader = { level = 5, name = "副盟主", max = 2  },
    strategist  = { level = 4, name = "军师",   max = 4  },
    vanguard    = { level = 3, name = "先锋官", max = 4  },
    diplomat    = { level = 2, name = "外交官", max = 2  },
    elite       = { level = 1, name = "精英",   max = -1 }, -- 不限
    member      = { level = 0, name = "成员",   max = -1 }, -- 不限
}

    -- 好友公共申请池 (排行榜模拟公共信箱)
local ROLE_SUCCESSION = { "vice_leader", "strategist", "vanguard", "diplomat", "elite", "member" }

--- 获取角色等级 (数字越大权限越高)
local function _getRoleLevel(role)
    local def = FACTION_ROLES[role or "member"]
    return def and def.level or 0
end

--- 获取角色中文名
local function _getRoleName(role)
    local def = FACTION_ROLES[role or "member"]
    return def and def.name or "成员"
end

--- 检查操作者是否有权对目标执行操作 (操作者等级必须高于目标)
local function _hasAuthorityOver(operatorRole, targetRole)
    return _getRoleLevel(operatorRole) > _getRoleLevel(targetRole)
end

--- 统计指定角色当前人数
local function _countRole(roles, roleName)
    local count = 0
    for _, r in pairs(roles or {}) do
        if r == roleName then count = count + 1 end
    end
    return count
end

-- 封禁系统常量
local BAN_LEVEL_NONE    = 0  -- 无封禁
local BAN_LEVEL_SOCIAL  = 1  -- 社交封禁(无法好友/阵营)
local BAN_LEVEL_CORE    = 2  -- 核心封禁(无法排行/竞技/抽卡)
local BAN_LEVEL_FULL    = 3  -- 全封禁(只能看不能玩)

-- 频率限制常量 (秒)
local COOLDOWN_FRIEND_REQUEST  = 30   -- 好友申请间隔
local COOLDOWN_PROFILE_PUBLISH = 300  -- 档案发布间隔(5分钟)
local COOLDOWN_SAVE_ALL        = 10   -- 全量保存间隔
local COOLDOWN_REJECTED_RETRY  = 86400 -- 被拒绝后重新申请冷却(24小时)

    -- 阵营聊天 (每人发布自己的最近消息, 轮询合并)
local HASH_SEED = 37829
local HASH_SECRET = 0x5F3759DF

-- ============================================================================
-- 共享可变状态 (子模块通过 CloudManager._S 访问)
-- ============================================================================
local S = {}
CloudManager._S = S

S.initialized = false
S.retryCount = 0
S.retryTimer = 0
S.retryData = nil
S.lastSyncTime = 0

S.banLevel = BAN_LEVEL_NONE      -- 当前玩家的封禁等级
S.banReason = ""                 -- 封禁原因
S.banChecked = false             -- 是否已完成封禁检查

S.cooldownTimestamps = {}        -- 频率限制: 各操作最后执行时间戳
S.rejectedByCache = {}           -- 被拒绝记录: { [targetUid] = rejectTime }

S.cloudLoadPending = false       -- 云端加载中标志
S.cloudLoadStartTime = 0         -- 云端加载开始时间 (os.clock)
S.cloudSyncNeeded = false        -- 服务端就绪后需补偿同步 (初次加载时服务端未就绪)
S.pendingSaveCallback = nil      -- 云端加载期间积攒的保存请求

-- ============================================================================
-- 初始化
-- ============================================================================

---@param opts? { prefix?: string, onBanned?: fun(level: number, reason: string) }
function CloudManager.Init(opts)
    if opts and opts.prefix then
        -- 允许覆盖前缀(测试用)
    end
    S.initialized = true
    print("[CloudManager] 初始化完成, prefix=" .. PREFIX)

    -- 启动时先检查封禁状态 (封禁检查优先于一切)
    CloudManager.CheckBanStatus(function(level, reason)
        if level >= BAN_LEVEL_FULL then
            print("[CloudManager] 玩家被全封禁: " .. tostring(reason))
            if opts and opts.onBanned then
                opts.onBanned(level, reason)
            end
            return -- 全封禁: 不加载任何数据
        end
        if level >= BAN_LEVEL_SOCIAL then
            print("[CloudManager] 玩家被社交封禁: " .. tostring(reason))
        end
        -- 非全封禁: 正常加载好友/阵营出站信箱
        if level < BAN_LEVEL_SOCIAL then
            CloudManager._loadMyOutbox()
        end
    end)
end

-- ============================================================================
-- 数据打包: 将游戏全局变量按 domain 打包
-- ============================================================================

--- 收集指定 domain 的数据 (从全局变量读取)
---@param domain string
---@return table
function CloudManager.CollectDomainData(domain)
    local now = os.time()

    if domain == "core" then
        return {
            savedAt = now,
            saveVersion = SAVE_VERSION,
            playerInfo = {
                name = playerInfo.name, level = playerInfo.level, exp = playerInfo.exp,
                rankIdx = playerInfo.rankIdx, jade = playerInfo.jade, avatarIdx = playerInfo.avatarIdx,
                profileSet = playerInfo.profileSet, abyssTickets = playerInfo.abyssTickets,
                lingshi = playerInfo.lingshi, totalBattles = playerInfo.totalBattles,
                totalWins = playerInfo.totalWins, totalGachas = playerInfo.totalGachas,
                totalEquips = playerInfo.totalEquips, totalDecompose = playerInfo.totalDecompose,
                totalEnhance = playerInfo.totalEnhance,
                ad_free = playerInfo.ad_free or false,
                tradeData = playerInfo.tradeData,
                tradeProcessed = playerInfo.tradeProcessed,
            },
        }

    elseif domain == "heroes" then
        return {
            savedAt = now,
            playerHeroes = playerHeroes,
            heroFragments = heroFragments,
        }

    elseif domain == "equip" then
        return {
            savedAt = now,
            playerEquipment = playerEquipment,
        }

    elseif domain == "skills" then
        local ul = {}
        for i, sk in pairs(SKILL_DEFS) do
            if sk.unlocked then ul[#ul + 1] = i end
        end
        return {
            savedAt = now,
            playerEquippedSkills = playerEquippedSkills,
            unlockedSkills = ul,
            skillFragments = skillFragments,
            skillLayers = skillLayers,
        }

    elseif domain == "progress" then
        return {
            savedAt = now,
            stageMaxUnlocked = stageState.maxUnlocked,
            stageCurrentPage = stageState.currentPage,
            stageStars = stageStars,
            stageStarClaimed = stageStarClaimed,
            stageChestClaimed = stageChestClaimed,
            abyssCleared = abyssCleared,
            towerHighestFloor = towerState.highestFloor,
            towerCurrentFloor = towerState.currentFloor,
            rankedScore = rankedState.score,
            rankedWins = rankedState.wins,
            rankedLosses = rankedState.losses,
            rankedStreak = rankedState.streak,
            rankedHighestScore = rankedState.highestScore,
            gachaPity = gachaState.pityCounter,
            limitedGachaPity = gachaState.limitedPityCounter,
        }

    elseif domain == "welfare" then
        -- nil 保护: 这些全局变量可能在首次登录时尚未初始化
        local ws = rawget(_G, "welfareState") or {}
        local sw = ws.spinWheel or {}
        local cf = ws.cardFlip or {}
        local ml = ws.mail or {}
        local dds = rawget(_G, "dailyDungeonState") or {}
        local rds = rawget(_G, "resourceDungeonState") or {}
        local bps = rawget(_G, "battlePassState") or {}
        local gs = rawget(_G, "gameSettings") or {}

        return {
            savedAt = now,
            dailyTaskState = rawget(_G, "dailyTaskState") or {},
            weeklyTaskState = rawget(_G, "weeklyTaskState") or {},
            achievementClaimed = rawget(_G, "achievementClaimed") or {},
            welfareState = {
                signInClaimed = ws.signInClaimed,
                signInTimestamps = ws.signInTimestamps,
                dailySignInClaimed = ws.dailySignInClaimed,
                dailySignInTimestamps = ws.dailySignInTimestamps,
                onlineRewards = ws.onlineRewards,
                onlineTime = ws.onlineTime,

                spinWheel = {
                    lastDate = sw.lastDate,
                    freeUsed = sw.freeUsed,
                    adSpins = sw.adSpins,
                },
                cardFlip = {
                    lastDate = cf.lastDate,
                    freeUsed = cf.freeUsed,
                    adFlips = cf.adFlips,
                    cards = cf.cards,
                    flipped = cf.flipped,
                },
            },
            cdkRedeemed = rawget(_G, "cdkState") and cdkState.redeemed or {},
            mailClaimed = ml.claimed or {},
            cloudMailClaimed = CloudManager._mailClaimed or {},
            lastWeeklySettled = ws.lastWeeklySettled,

            sealData = rawget(_G, "sealData"),
            sealExpItems = rawget(_G, "sealExpItems"),
            sealInventory = rawget(_G, "sealInventory"),
            sealInventoryNextId = rawget(_G, "sealInventoryNextId"),
            dailyDungeonState = {
                lastResetDay = dds.lastResetDay,
                completed = dds.completed,
                todaySlot = dds.todaySlot,
                selectedSet = dds.selectedSet,
            },
            resourceDungeonState = {
                lastResetDay = rds.lastResetDay,
                completed = rds.completed,
            },
            battlePassState = {
                seasonStartDay = bps.seasonStartDay,
                level = bps.level,
                exp = bps.exp,
                dailyProgress = bps.dailyProgress,
                weeklyProgress = bps.weeklyProgress,
                seasonProgress = bps.seasonProgress,
                dailyClaimed = bps.dailyClaimed,
                weeklyClaimed = bps.weeklyClaimed,
                seasonClaimed = bps.seasonClaimed,
                freeRewardClaimed = bps.freeRewardClaimed,
                premiumRewardClaimed = bps.premiumRewardClaimed,
                lastDailyReset = bps.lastDailyReset,
                lastWeeklyReset = bps.lastWeeklyReset,
            },
        }

    elseif domain == "social" then
        return {
            savedAt = now,
            friendIds = CloudManager._friendIds or {},
            factionId = CloudManager._factionId or 0,
            factionName = CloudManager._factionName or "",
            factionRole = CloudManager._factionRole or "none",  -- "leader" / "member" / "none"
        }

    elseif domain == "explore" then
        local exploreData = nil
        if rawget(_G, "Exploration") and Exploration.GetState then
            exploreData = Exploration.GetState()
        end
        return {
            savedAt = now,
            explorationState = exploreData,
        }

    elseif domain == "worldmap" then
        local wm = rawget(_G, "WorldMap")
        local wms = rawget(_G, "worldMapState")
        if wm and wms and wms.inited then
            -- 收集城池运行时数据
            local citySave = {}
            for _, c in ipairs(WORLD_CITIES) do
                local cd = wms.cityData[c.id]
                if cd then
                    citySave[tostring(c.id)] = {
                        owner = cd.owner,
                        garrison = cd.garrison,
                        level = cd.level,
                        heroes = cd.heroes,
                        morale = cd.morale or 80,
                    }
                end
            end
            -- 序列化兵种选择 (key从number转string, JSON兼容)
            local troopChoiceSave = {}
            for k, v in pairs(wms.heroTroopChoice or {}) do
                troopChoiceSave[tostring(k)] = v
            end
            -- 序列化已学武技
            local learnedSave = {}
            for k, v in pairs(wms.heroLearnedSkills or {}) do
                learnedSave[tostring(k)] = v
            end
            return {
                savedAt = now,
                turn = wms.turn,
                totalTurns = wms.totalTurns or wms.turn,
                gold = wms.gold,
                food = wms.food or 300,
                troops = wms.troops,
                playerFaction = wms.playerFaction,
                cityData = citySave,
                diplomacy = wms.diplomacy,
                heroTroopChoice = troopChoiceSave,
                heroLearnedSkills = learnedSave,
            }
        end
        return { savedAt = now }
    end

    return { savedAt = now }
end

-- ============================================================================
-- 全量保存 (本地 + 云端多domain)
-- ============================================================================

--- 全量保存: 本地JSON + 云端多domain BatchSet
---@param callback? fun(success: boolean, msg: string)
---@param forceBypass? boolean 跳过频率限制(内部用)
function CloudManager.SaveAll(callback, forceBypass)
    -- 封禁检查: 全封禁禁止保存
    if S.banLevel >= BAN_LEVEL_FULL then
        if callback then callback(false, "账号已被封禁, 无法保存") end
        return
    end

    -- 云端加载中保护: 只保存本地, 不上传云端 (防止旧数据覆盖云端新数据)
    if S.cloudLoadPending then
        print("[CloudManager] 云端加载中, 仅保存本地 (防止竞态覆盖)")
        CloudManager._sanitizeResources()
        local allData = {}
        for name, _ in pairs(DOMAINS) do
            allData[name] = CloudManager.CollectDomainData(name)
        end
        CloudManager._saveLocalJSON(allData)
        -- 记录待保存回调, LoadAll 完成后会触发一次完整 SaveAll
        S.pendingSaveCallback = callback
        return
    end

    -- 频率限制: 防止高频保存 (但本地文件仍然保存)
    if not forceBypass and not CloudManager._checkCooldown("save_all", COOLDOWN_SAVE_ALL) then
        -- 即使被冷却阻断, 仍然保存本地文件 (防止崩溃丢失数据)
        CloudManager._sanitizeResources()
        local allData = {}
        for name, _ in pairs(DOMAINS) do
            allData[name] = CloudManager.CollectDomainData(name)
        end
        CloudManager._saveLocalJSON(allData)
        if callback then callback(false, "保存过于频繁, 仅本地保存") end
        return
    end

    -- 0. 负值防护: 关键资源不允许为负
    CloudManager._sanitizeResources()

    -- 1. 收集所有 domain 数据
    local allData = {}
    for name, _ in pairs(DOMAINS) do
        allData[name] = CloudManager.CollectDomainData(name)
    end

    -- 2. 保存本地JSON (保留完整单文件兜底)
    CloudManager._saveLocalJSON(allData)

    -- 3. 云端 BatchSet (多domain + 公开档案)
    if not CloudAPI.IsAvailable() then
        if callback then callback(true, "本地保存成功(无云端)") end
        return
    end

    -- 安全检查: 防止空数据覆盖有效存档
    local coreData = allData.core
    if coreData and coreData.playerInfo then
        local pi = coreData.playerInfo
        local weight = (pi.totalBattles or 0) + (pi.totalWins or 0)
            + (pi.rankIdx or 0) * 100 + (pi.totalGachas or 0) + (pi.totalEquips or 0)
        if weight <= 100 and not pi.profileSet then
            print("[CloudManager] 跳过云端同步: 数据权重过低(" .. tostring(weight) .. ")")
        if callback then callback(true, "本地保存成功(无云端)") end
            return
        end
    end

    -- 构建 BatchSet
    local batch = CloudAPI:BatchSet()
    for name, key in pairs(DOMAINS) do
        batch:Set(key, allData[name])
    end

    -- 同时更新旧格式 savegame key (向下兼容)
    local legacyData = CloudManager._buildLegacyData(allData)
    batch:Set(KEYS.legacy_save, legacyData)

    -- 计算并保存存档哈希
    local hash = CloudManager._computeSaveHash(allData)
    batch:Set(KEYS.save_hash, { hash = hash, time = os.time() })

    batch:Save("CloudManager.SaveAll", {
        ok = function()
            print("[CloudManager] 云端多domain同步成功")
            S.retryCount = 0
            S.lastSyncTime = os.time()
            if callback then callback(true, "云端同步成功") end
        end,
        error = function(code, reason)
            print("[CloudManager] 云端同步失败: " .. tostring(code) .. " " .. tostring(reason))
            S.retryCount = S.retryCount + 1
            if S.retryCount <= 3 then
                S.retryTimer = 30
                S.retryData = allData
            end
            if callback then callback(false, tostring(reason)) end
        end,
    })

    -- 4. 发布公开档案 (异步，不阻塞保存, 有频率限制)
    CloudManager._publishProfile(allData)
end

--- 单域保存 (仅更新指定domain)
---@param domain string domain名称
---@param callback? fun(success: boolean)
function CloudManager.SaveDomain(domain, callback)
    local key = DOMAINS[domain]
    if not key then
        print("[CloudManager] 未知domain: " .. tostring(domain))
        return
    end

    local data = CloudManager.CollectDomainData(domain)

    -- 更新本地JSON (全量重写)
    CloudManager._saveLocalJSON(nil) -- 触发全量本地保存

    if not CloudAPI.IsAvailable() then
        if callback then callback(true) end
        return
    end

    CloudAPI:Set(key, data, {
        ok = function()
            print("[CloudManager] domain " .. domain .. " 云端保存成功")
            if callback then callback(true) end
        end,
        error = function(code, reason)
            print("[CloudManager] domain " .. domain .. " 云端保存失败: " .. tostring(reason))
            if callback then callback(false) end
        end,
    })
end

-- ============================================================================
-- 全量加载 (本地优先 + 云端对比)
-- ============================================================================

--- 全量加载: 先加载本地 -> 再对比云端取更新的
---@param callback? fun(source: string) "local" | "cloud" | "none"
function CloudManager.LoadAll(callback)
    -- 1. 加载本地
    local localData = CloudManager._loadLocalJSON()
    local localVersion = nil

    if localData then
        -- 判断是旧格式还是新格式
        if localData._multiDomain then
            -- 新格式: 按domain恢复
            localVersion = "multi"
            CloudManager._applyMultiDomain(localData)
        else
            -- 旧格式: 用原有 ApplySaveData
            localVersion = "legacy"
            if rawget(_G, "ApplySaveData") then
                ApplySaveData(localData)
            end
        end
        print("[CloudManager] 本地存档已加载, format=" .. localVersion)
    else
        print("[CloudManager] 本地无存档")
    end

    -- 2. 云端对比 (必须用 IsReady: 服务端已连接且收到 Welcome 才走云端路径,
    --    否则请求会进入 delayedCloudQueue_ 永远等不到响应, cloudLoadPending 卡死)
    if not CloudAPI.IsReady() then
        print("[CloudManager] 服务端未就绪(IsReady=false), 跳过云端加载, 使用本地存档")
        S.cloudSyncNeeded = true  -- 标记: 服务端就绪后需补偿同步
        if callback then callback(localData and "local" or "none") end
        return
    end

    -- 设置云端加载中标志, 防止 SaveAll 在此期间覆盖云端数据
    S.cloudLoadPending = true
    S.cloudLoadStartTime = os.clock()
    S.pendingSaveCallback = nil
    print("[CloudManager] 开始云端加载, 已锁定云端写入")

    -- BatchGet 所有 domain + 旧格式key + 哈希校验
    local batchGet = CloudAPI:BatchGet()
    for _, key in pairs(DOMAINS) do
        batchGet:Key(key)
    end
    batchGet:Key(KEYS.legacy_save)
    batchGet:Key(KEYS.save_hash)

    batchGet:Fetch({
        ok = function(values, iscores)
            -- 检查云端是否有新格式数据
            local cloudHasMulti = values[DOMAINS.core] ~= nil
            local cloudHasLegacy = values[KEYS.legacy_save] ~= nil

            if not cloudHasMulti and not cloudHasLegacy then
                -- 云端无存档, 上传本地
                S.cloudLoadPending = false
                print("[CloudManager] 云端加载完成(无云端存档)，已解锁云端写入")
                if localData then
                    print("[CloudManager] 云端无存档, 上传本地")
                    CloudManager.SaveAll()
                end
                if callback then callback(localData and "local" or "none") end
                return
            end

            -- 获取云端时间戳
            local cloudTime = 0
            if cloudHasMulti then
                local coreData = values[DOMAINS.core]
                cloudTime = (coreData and coreData.savedAt) or 0
            elseif cloudHasLegacy then
                local legData = values[KEYS.legacy_save]
                cloudTime = (legData and legData.savedAt) or 0
            end

            -- 获取本地时间戳
            local localTime = 0
            if localData then
                if localVersion == "multi" and localData.domains and localData.domains.core then
                    localTime = localData.domains.core.savedAt or 0
                elseif localData.savedAt then
                    localTime = localData.savedAt
                end
            end

            -- 对比决策
            -- 关键数据诊断: 在决策前记录本地和云端的兵符/玉壁值
            local localJade = rawget(_G, "playerInfo") and playerInfo.jade or -1
            local localSealCount = 0
            if rawget(_G, "sealData") then
                for _ in pairs(sealData) do localSealCount = localSealCount + 1 end
            end
            local cloudJade = -1
            local cloudSealCount = 0
            if cloudHasMulti and values[DOMAINS.core] and values[DOMAINS.core].playerInfo then
                cloudJade = values[DOMAINS.core].playerInfo.jade or -1
            end
            if cloudHasMulti and values[DOMAINS.welfare] and values[DOMAINS.welfare].sealData then
                for _ in pairs(values[DOMAINS.welfare].sealData) do cloudSealCount = cloudSealCount + 1 end
            end
            print(string.format("[CloudManager] 数据对比: 本地jade=%s sealCount=%d | 云端jade=%s sealCount=%d",
                tostring(localJade), localSealCount, tostring(cloudJade), cloudSealCount))

            local useCloud = false
            if not localData then
                useCloud = true
                print("[CloudManager] 本地无存档, 使用云端")
            elseif cloudTime > 0 and localTime > 0 then
                useCloud = cloudTime > localTime
                print(string.format("[CloudManager] 本地time=%d vs 云端time=%d -> %s",
                    localTime, cloudTime, useCloud and "用云端" or "用本地"))
            end

            if useCloud then
                if cloudHasMulti then
                    -- 新格式: 按domain恢复
                    local cloudDomains = {}
                    for name, key in pairs(DOMAINS) do
                        cloudDomains[name] = values[key]
                    end
                    -- 哈希校验: 验证云端存档完整性
                    local storedHashData = values[KEYS.save_hash]
                    if storedHashData and storedHashData.hash then
                        local recalcHash = CloudManager._computeSaveHash(cloudDomains)
                        if recalcHash ~= storedHashData.hash then
                            print("[CloudManager] 云端存档哈希校验失败! stored="
                                .. tostring(storedHashData.hash) .. " calc=" .. tostring(recalcHash))
                            -- 存档可能被篡改: 仍然加载但标记警告
                            CloudManager._hashMismatch = true
                        else
                            CloudManager._hashMismatch = false
                        end
                    end
                    CloudManager._applyMultiDomain({ domains = cloudDomains })
                    -- 负值防护
                    CloudManager._sanitizeResources()
                    -- 保存到本地
                    CloudManager._saveLocalJSON(nil)
            print("[CloudManager] 云端多domain同步成功")
                else
                    -- 旧格式
                    local legData = values[KEYS.legacy_save]
                    if rawget(_G, "ApplySaveData") then
                        ApplySaveData(legData)
                    end
                    CloudManager._saveLocalJSON(nil)
        print("[CloudManager] 本地无存档")
                end
                if callback then callback("cloud") end
            else
                -- 本地更新, 同步到云端
                CloudManager.SaveAll()
                if callback then callback("local") end
            end

            -- 解锁云端写入
            S.cloudLoadPending = false
            print("[CloudManager] 云端加载完成, 已解锁云端写入")

            -- 如果加载期间有延迟的保存请求, 现在执行一次完整 SaveAll
            if S.pendingSaveCallback then
                local cb = S.pendingSaveCallback
                S.pendingSaveCallback = nil
        print("[CloudManager] 本地无存档")
                CloudManager.SaveAll(cb, true) -- forceBypass=true 跳过冷却
            end

            -- 好友/阵营信箱: 拉取出站数据 (申请池模式)
            CloudManager._loadMyOutbox()
        end,
        error = function(code, reason)
            print("[CloudManager] 玩家被全封禁: " .. tostring(reason))
            -- 解锁云端写入 (即使失败也要解锁, 否则永远无法保存到云端)
            S.cloudLoadPending = false
            print("[CloudManager] 云端加载失败, 已解锁云端写入")
            -- 执行延迟保存
            if S.pendingSaveCallback then
                local cb = S.pendingSaveCallback
                S.pendingSaveCallback = nil
                CloudManager.SaveAll(cb, true)
            end
            if callback then callback(localData and "local" or "none") end
        end,
    })
end

-- ============================================================================
-- 导出常量/工具函数供子模块使用 (子模块通过 CloudManager._C 访问)
-- ============================================================================
CloudManager._C = {
    PREFIX = PREFIX,
    DOMAINS = DOMAINS,
    KEYS = KEYS,
    MAX_FRIENDS = MAX_FRIENDS,
    REQUEST_EXPIRE_SECONDS = REQUEST_EXPIRE_SECONDS,
    MAX_OUTBOX = MAX_OUTBOX,
    MAX_CAMP_MEMBERS = MAX_CAMP_MEMBERS,
    CAMP_CREATE_COST = CAMP_CREATE_COST,
    SAVE_VERSION = SAVE_VERSION,
    FACTION_ROLES = FACTION_ROLES,
    ROLE_SUCCESSION = ROLE_SUCCESSION,
    BAN_LEVEL_NONE = BAN_LEVEL_NONE,
    BAN_LEVEL_SOCIAL = BAN_LEVEL_SOCIAL,
    BAN_LEVEL_CORE = BAN_LEVEL_CORE,
    BAN_LEVEL_FULL = BAN_LEVEL_FULL,
    COOLDOWN_FRIEND_REQUEST = COOLDOWN_FRIEND_REQUEST,
    COOLDOWN_PROFILE_PUBLISH = COOLDOWN_PROFILE_PUBLISH,
    COOLDOWN_SAVE_ALL = COOLDOWN_SAVE_ALL,
    COOLDOWN_REJECTED_RETRY = COOLDOWN_REJECTED_RETRY,
    HASH_SEED = HASH_SEED,
    HASH_SECRET = HASH_SECRET,
    _getRoleLevel = _getRoleLevel,
    _getRoleName = _getRoleName,
    _hasAuthorityOver = _hasAuthorityOver,
    _countRole = _countRole,
}

