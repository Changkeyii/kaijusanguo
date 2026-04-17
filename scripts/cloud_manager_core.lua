-- ============================================================================
-- cloud_manager_core.lua - 涓夊浗姝︾伒褰?(浠?cloud_manager.lua 鎷嗗垎)
-- 鏍稿績瀛樺偍: Init, CollectDomainData, SaveAll, SaveDomain, LoadAll
-- ============================================================================
---@diagnostic disable: undefined-global

CloudManager = {}

-- ============================================================================
-- 甯搁噺 & 閰嶇疆
-- ============================================================================
local PREFIX = "p_49dd_"

-- 涓汉瀛樻。 domain 瀹氫箟
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

-- 鍏紑/绀句氦 key
local KEYS = {
    combat_power  = PREFIX .. "combat_power",
    pub_profile   = PREFIX .. "pub_profile",
    realm_level   = PREFIX .. "realm_level",
    -- 濂藉弸鍏叡鐢宠姹?(鎺掕姒滄ā鎷熷叕鍏变俊绠?
    freq_outbox_ts = PREFIX .. "freq_outbox_ts",  -- SetInt: 鏈€鏂扮敵璇锋椂闂存埑 (鎺掕鐢?
    freq_outbox    = PREFIX .. "freq_outbox",      -- Set: 鍑虹珯鐢宠鍒楄〃 JSON
    freq_resp_ts   = PREFIX .. "freq_resp_ts",     -- SetInt: 鏈€鏂板洖澶嶆椂闂存埑
    freq_resp      = PREFIX .. "freq_resp",        -- Set: 鍥炲鍒楄〃 JSON
    -- 闃佃惀鍏叡瀛樺偍 (鎺掕姒滄ā鎷熼樀钀ユ€昏〃)
    camp_leader_ts = PREFIX .. "camp_leader_ts",   -- SetInt: 闃佃惀鍒涘缓鏃堕棿 (鎺掕鐢? 浠呯洘涓?
    camp_meta      = PREFIX .. "camp_meta",        -- Set: 闃佃惀鍏冩暟鎹?(浠呯洘涓荤淮鎶?
    camp_apply_ts  = PREFIX .. "camp_apply_ts",    -- SetInt: 鍏ヨ惀鐢宠鏃堕棿
    camp_apply     = PREFIX .. "camp_apply",       -- Set: 鍏ヨ惀鐢宠 JSON
    camp_resp_ts   = PREFIX .. "camp_resp_ts",     -- SetInt: 鐩熶富瀹℃壒鍥炲鏃堕棿
    camp_resp      = PREFIX .. "camp_resp",        -- Set: 瀹℃壒鍥炲 JSON
    -- 闃佃惀鑱婂ぉ (姣忎汉鍙戝竷鑷繁鐨勬渶杩戞秷鎭? 杞鍚堝苟)
    camp_chat_ts   = PREFIX .. "camp_chat_ts",      -- SetInt: 鏈€鏂拌亰澶╂椂闂存埑 (鎺掕鐢?
    camp_chat      = PREFIX .. "camp_chat",          -- Set: 鏈€杩戞秷鎭垪琛?JSON [{text,time,ts}]
    world_chat_ts  = PREFIX .. "world_chat_ts",      -- SetInt: 涓栫晫鑱婂ぉ鏃堕棿鎴?(鎺掕鐢?
    world_chat     = PREFIX .. "world_chat",          -- Set: 涓栫晫鑱婂ぉ娑堟伅鍒楄〃
    -- 灏佺绯荤粺 (寮€鍙戣€呴€氳繃鎺掕姒滃彂甯冨皝绂佸悕鍗?
    ban_ts        = PREFIX .. "ban_ts",            -- SetInt: 灏佺鍙戝竷鏃堕棿
    ban_data      = PREFIX .. "ban_data",           -- Set: 灏佺鍚嶅崟 JSON
    -- 瀛樻。鏍￠獙
    save_hash     = PREFIX .. "save_hash",          -- Set: 瀛樻。鍝堝笇鏍￠獙鍊?
    -- 鍏煎鏃у瓨妗?
    legacy_save   = PREFIX .. "savegame",
    -- 鐜╁閭欢 (鍏叡淇＄妯″紡)
    mail_ts       = PREFIX .. "mail_ts",           -- SetInt: 鏈€鏂板彂浠舵椂闂存埑 (鎺掕鐢?
    mail_outbox   = PREFIX .. "mail_outbox",       -- Set: 鍙戜欢绠?JSON [{to,subject,body,rewards,time,id}]
}

local MAX_FRIENDS = 50
local REQUEST_EXPIRE_SECONDS = 7 * 86400  -- 鐢宠7澶╄繃鏈?
local MAX_OUTBOX = 20       -- 姣忎汉鏈€澶?0鏉″緟澶勭悊鍑虹珯鐢宠
local MAX_CAMP_MEMBERS = 20 -- 闃佃惀鏈€澶т汉鏁帮紙1绾ч樀钀ヤ笂闄愶級
local CAMP_CREATE_COST = 5000 -- 鍒涘缓闃佃惀娑堣€楄檸绗?
local SAVE_VERSION = 2  -- 瀛樻。鐗堟湰 (1=鏃у崟key, 2=鏂板domain)

-- ============================================================================
-- 闃佃惀鑱屼綅浣撶郴 (浠跨巼鍦熶箣婊ㄥ悓鐩?
-- 缁ф壙閾? leader 鈫?vice_leader 鈫?strategist 鈫?vanguard 鈫?diplomat 鈫?elite 鈫?member
-- ============================================================================
local FACTION_ROLES = {
    leader      = { level = 6, name = "鐩熶富",   max = 1  },
    vice_leader = { level = 5, name = "鍓洘涓?, max = 2  },
    strategist  = { level = 4, name = "鍐涘笀",   max = 4  },
    vanguard    = { level = 3, name = "鍏堥攱瀹?, max = 4  },
    diplomat    = { level = 2, name = "澶栦氦瀹?, max = 2  },
    elite       = { level = 1, name = "绮捐嫳",   max = -1 }, -- 涓嶉檺
    member      = { level = 0, name = "鎴愬憳",   max = -1 }, -- 涓嶉檺
}

-- 鎸夌瓑绾ч檷搴忔帓鍒楃殑瑙掕壊鍒楄〃 (鐢ㄤ簬缁ф壙閾鹃亶鍘?
local ROLE_SUCCESSION = { "vice_leader", "strategist", "vanguard", "diplomat", "elite", "member" }

--- 鑾峰彇瑙掕壊绛夌骇 (鏁板瓧瓒婂ぇ鏉冮檺瓒婇珮)
local function _getRoleLevel(role)
    local def = FACTION_ROLES[role or "member"]
    return def and def.level or 0
end

--- 鑾峰彇瑙掕壊涓枃鍚?
local function _getRoleName(role)
    local def = FACTION_ROLES[role or "member"]
    return def and def.name or "鎴愬憳"
end

--- 妫€鏌ユ搷浣滆€呮槸鍚︽湁鏉冨鐩爣鎵ц鎿嶄綔 (鎿嶄綔鑰呯瓑绾у繀椤婚珮浜庣洰鏍?
local function _hasAuthorityOver(operatorRole, targetRole)
    return _getRoleLevel(operatorRole) > _getRoleLevel(targetRole)
end

--- 缁熻鎸囧畾瑙掕壊褰撳墠浜烘暟
local function _countRole(roles, roleName)
    local count = 0
    for _, r in pairs(roles or {}) do
        if r == roleName then count = count + 1 end
    end
    return count
end

-- 灏佺绯荤粺甯搁噺
local BAN_LEVEL_NONE    = 0  -- 鏃犲皝绂?
local BAN_LEVEL_SOCIAL  = 1  -- 绀句氦灏佺(鏃犳硶濂藉弸/闃佃惀)
local BAN_LEVEL_CORE    = 2  -- 鏍稿績灏佺(鏃犳硶鎺掕/绔炴妧/鎶藉崱)
local BAN_LEVEL_FULL    = 3  -- 鍏ㄥ皝绂?鍙兘鐪嬩笉鑳界帺)

-- 棰戠巼闄愬埗甯搁噺 (绉?
local COOLDOWN_FRIEND_REQUEST  = 30   -- 濂藉弸鐢宠闂撮殧
local COOLDOWN_PROFILE_PUBLISH = 300  -- 妗ｆ鍙戝竷闂撮殧(5鍒嗛挓)
local COOLDOWN_SAVE_ALL        = 10   -- 鍏ㄩ噺淇濆瓨闂撮殧
local COOLDOWN_REJECTED_RETRY  = 86400 -- 琚嫆缁濆悗閲嶆柊鐢宠鍐峰嵈(24灏忔椂)

-- 鍝堝笇鏍￠獙瀵嗛挜 (娣锋穯鐢? 闈炲姞瀵嗗畨鍏?
local HASH_SEED = 37829
local HASH_SECRET = 0x5F3759DF

-- ============================================================================
-- 鍏变韩鍙彉鐘舵€?(瀛愭ā鍧楅€氳繃 CloudManager._S 璁块棶)
-- ============================================================================
local S = {}
CloudManager._S = S

S.initialized = false
S.retryCount = 0
S.retryTimer = 0
S.retryData = nil
S.lastSyncTime = 0

S.banLevel = BAN_LEVEL_NONE      -- 褰撳墠鐜╁鐨勫皝绂佺瓑绾?
S.banReason = ""                 -- 灏佺鍘熷洜
S.banChecked = false             -- 鏄惁宸插畬鎴愬皝绂佹鏌?

S.cooldownTimestamps = {}        -- 棰戠巼闄愬埗: 鍚勬搷浣滄渶鍚庢墽琛屾椂闂存埑
S.rejectedByCache = {}           -- 琚嫆缁濊褰? { [targetUid] = rejectTime }

S.cloudLoadPending = false       -- 浜戠鍔犺浇涓爣蹇?
S.pendingSaveCallback = nil      -- 浜戠鍔犺浇鏈熼棿绉敀鐨勪繚瀛樿姹?

-- ============================================================================
-- 鍒濆鍖?
-- ============================================================================

---@param opts? { prefix?: string, onBanned?: fun(level: number, reason: string) }
function CloudManager.Init(opts)
    if opts and opts.prefix then
        -- 鍏佽瑕嗙洊鍓嶇紑(娴嬭瘯鐢?
    end
    S.initialized = true
    print("[CloudManager] 鍒濆鍖栧畬鎴? prefix=" .. PREFIX)

    -- 鍚姩鏃跺厛妫€鏌ュ皝绂佺姸鎬?(灏佺妫€鏌ヤ紭鍏堜簬涓€鍒?
    CloudManager.CheckBanStatus(function(level, reason)
        if level >= BAN_LEVEL_FULL then
            print("[CloudManager] 鐜╁琚叏灏佺: " .. tostring(reason))
            if opts and opts.onBanned then
                opts.onBanned(level, reason)
            end
            return -- 鍏ㄥ皝绂? 涓嶅姞杞戒换浣曟暟鎹?
        end
        if level >= BAN_LEVEL_SOCIAL then
            print("[CloudManager] 鐜╁琚ぞ浜ゅ皝绂? " .. tostring(reason))
        end
        -- 闈炲叏灏佺: 姝ｅ父鍔犺浇濂藉弸/闃佃惀鍑虹珯淇＄
        if level < BAN_LEVEL_SOCIAL then
            CloudManager._loadMyOutbox()
        end
    end)
end

-- ============================================================================
-- 鏁版嵁鎵撳寘: 灏嗘父鎴忓叏灞€鍙橀噺鎸?domain 鎵撳寘
-- ============================================================================

--- 鏀堕泦鎸囧畾 domain 鐨勬暟鎹?(浠庡叏灞€鍙橀噺璇诲彇)
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
        -- nil 淇濇姢: 杩欎簺鍏ㄥ眬鍙橀噺鍙兘鍦ㄩ娆＄櫥褰曟椂灏氭湭鍒濆鍖?
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
            tutorialRewardClaimed = gs.tutorialRewardClaimed or false,
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
            -- 鏀堕泦鍩庢睜杩愯鏃舵暟鎹?
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
            -- 搴忓垪鍖栧叺绉嶉€夋嫨 (key浠巒umber杞瑂tring, JSON鍏煎)
            local troopChoiceSave = {}
            for k, v in pairs(wms.heroTroopChoice or {}) do
                troopChoiceSave[tostring(k)] = v
            end
            -- 搴忓垪鍖栧凡瀛︽鎶€
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
-- 鍏ㄩ噺淇濆瓨 (鏈湴 + 浜戠澶歞omain)
-- ============================================================================

--- 鍏ㄩ噺淇濆瓨: 鏈湴JSON + 浜戠澶歞omain BatchSet
---@param callback? fun(success: boolean, msg: string)
---@param forceBypass? boolean 璺宠繃棰戠巼闄愬埗(鍐呴儴鐢?
function CloudManager.SaveAll(callback, forceBypass)
    -- 灏佺妫€鏌? 鍏ㄥ皝绂佺姝繚瀛?
    if S.banLevel >= BAN_LEVEL_FULL then
        if callback then callback(false, "璐﹀彿宸茶灏佺, 鏃犳硶淇濆瓨") end
        return
    end

    -- 浜戠鍔犺浇涓繚鎶? 鍙繚瀛樻湰鍦? 涓嶄笂浼犱簯绔?(闃叉鏃ф暟鎹鐩栦簯绔柊鏁版嵁)
    if S.cloudLoadPending then
        print("[CloudManager] 浜戠鍔犺浇涓? 浠呬繚瀛樻湰鍦?(闃叉绔炴€佽鐩?")
        CloudManager._sanitizeResources()
        local allData = {}
        for name, _ in pairs(DOMAINS) do
            allData[name] = CloudManager.CollectDomainData(name)
        end
        CloudManager._saveLocalJSON(allData)
        -- 璁板綍寰呬繚瀛樺洖璋? LoadAll 瀹屾垚鍚庝細瑙﹀彂涓€娆″畬鏁?SaveAll
        S.pendingSaveCallback = callback
        return
    end

    -- 棰戠巼闄愬埗: 闃叉楂橀淇濆瓨 (浣嗘湰鍦版枃浠朵粛鐒朵繚瀛?
    if not forceBypass and not CloudManager._checkCooldown("save_all", COOLDOWN_SAVE_ALL) then
        -- 鍗充娇琚喎鍗撮樆鏂? 浠嶇劧淇濆瓨鏈湴鏂囦欢 (闃叉宕╂簝涓㈠け鏁版嵁)
        CloudManager._sanitizeResources()
        local allData = {}
        for name, _ in pairs(DOMAINS) do
            allData[name] = CloudManager.CollectDomainData(name)
        end
        CloudManager._saveLocalJSON(allData)
        if callback then callback(false, "淇濆瓨杩囦簬棰戠箒, 浠呮湰鍦颁繚瀛?) end
        return
    end

    -- 0. 璐熷€奸槻鎶? 鍏抽敭璧勬簮涓嶅厑璁镐负璐?
    CloudManager._sanitizeResources()

    -- 1. 鏀堕泦鎵€鏈?domain 鏁版嵁
    local allData = {}
    for name, _ in pairs(DOMAINS) do
        allData[name] = CloudManager.CollectDomainData(name)
    end

    -- 2. 淇濆瓨鏈湴JSON (淇濈暀瀹屾暣鍗曟枃浠跺厹搴?
    CloudManager._saveLocalJSON(allData)

    -- 3. 浜戠 BatchSet (澶歞omain + 鍏紑妗ｆ)
    if not CloudAPI.IsAvailable() then
        if callback then callback(true, "鏈湴淇濆瓨鎴愬姛(鏃犱簯绔?") end
        return
    end

    -- 瀹夊叏妫€鏌? 闃叉绌烘暟鎹鐩栨湁鏁堝瓨妗?
    local coreData = allData.core
    if coreData and coreData.playerInfo then
        local pi = coreData.playerInfo
        local weight = (pi.totalBattles or 0) + (pi.totalWins or 0)
            + (pi.rankIdx or 0) * 100 + (pi.totalGachas or 0) + (pi.totalEquips or 0)
        if weight <= 100 and not pi.profileSet then
            print("[CloudManager] 璺宠繃浜戠鍚屾: 鏁版嵁鏉冮噸杩囦綆(" .. tostring(weight) .. ")")
            if callback then callback(true, "鏈湴淇濆瓨鎴愬姛(鏉冮噸杩囦綆璺宠繃浜戠)") end
            return
        end
    end

    -- 鏋勫缓 BatchSet
    local batch = CloudAPI:BatchSet()
    for name, key in pairs(DOMAINS) do
        batch:Set(key, allData[name])
    end

    -- 鍚屾椂鏇存柊鏃ф牸寮?savegame key (鍚戜笅鍏煎)
    local legacyData = CloudManager._buildLegacyData(allData)
    batch:Set(KEYS.legacy_save, legacyData)

    -- 璁＄畻骞朵繚瀛樺瓨妗ｅ搱甯?
    local hash = CloudManager._computeSaveHash(allData)
    batch:Set(KEYS.save_hash, { hash = hash, time = os.time() })

    batch:Save("CloudManager.SaveAll", {
        ok = function()
            print("[CloudManager] 浜戠澶歞omain鍚屾鎴愬姛")
            S.retryCount = 0
            S.lastSyncTime = os.time()
            if callback then callback(true, "浜戠鍚屾鎴愬姛") end
        end,
        error = function(code, reason)
            print("[CloudManager] 浜戠鍚屾澶辫触: " .. tostring(code) .. " " .. tostring(reason))
            S.retryCount = S.retryCount + 1
            if S.retryCount <= 3 then
                S.retryTimer = 30
                S.retryData = allData
            end
            if callback then callback(false, tostring(reason)) end
        end,
    })

    -- 4. 鍙戝竷鍏紑妗ｆ (寮傛锛屼笉闃诲淇濆瓨, 鏈夐鐜囬檺鍒?
    CloudManager._publishProfile(allData)
end

--- 鍗曞煙淇濆瓨 (浠呮洿鏂版寚瀹歞omain)
---@param domain string domain鍚嶇О
---@param callback? fun(success: boolean)
function CloudManager.SaveDomain(domain, callback)
    local key = DOMAINS[domain]
    if not key then
        print("[CloudManager] 鏈煡domain: " .. tostring(domain))
        return
    end

    local data = CloudManager.CollectDomainData(domain)

    -- 鏇存柊鏈湴JSON (鍏ㄩ噺閲嶅啓)
    CloudManager._saveLocalJSON(nil) -- 瑙﹀彂鍏ㄩ噺鏈湴淇濆瓨

    if not CloudAPI.IsAvailable() then
        if callback then callback(true) end
        return
    end

    CloudAPI:Set(key, data, {
        ok = function()
            print("[CloudManager] domain " .. domain .. " 浜戠淇濆瓨鎴愬姛")
            if callback then callback(true) end
        end,
        error = function(code, reason)
            print("[CloudManager] domain " .. domain .. " 浜戠淇濆瓨澶辫触: " .. tostring(reason))
            if callback then callback(false) end
        end,
    })
end

-- ============================================================================
-- 鍏ㄩ噺鍔犺浇 (鏈湴浼樺厛 + 浜戠瀵规瘮)
-- ============================================================================

--- 鍏ㄩ噺鍔犺浇: 鍏堝姞杞芥湰鍦?-> 鍐嶅姣斾簯绔彇鏇存柊鐨?
---@param callback? fun(source: string) "local" | "cloud" | "none"
function CloudManager.LoadAll(callback)
    -- 1. 鍔犺浇鏈湴
    local localData = CloudManager._loadLocalJSON()
    local localVersion = nil

    if localData then
        -- 鍒ゆ柇鏄棫鏍煎紡杩樻槸鏂版牸寮?
        if localData._multiDomain then
            -- 鏂版牸寮? 鎸塪omain鎭㈠
            localVersion = "multi"
            CloudManager._applyMultiDomain(localData)
        else
            -- 鏃ф牸寮? 鐢ㄥ師鏈?ApplySaveData
            localVersion = "legacy"
            if rawget(_G, "ApplySaveData") then
                ApplySaveData(localData)
            end
        end
        print("[CloudManager] 鏈湴瀛樻。宸插姞杞? format=" .. localVersion)
    else
        print("[CloudManager] 鏈湴鏃犲瓨妗?)
    end

    -- 2. 浜戠瀵规瘮
    if not CloudAPI.IsAvailable() then
        if callback then callback(localData and "local" or "none") end
        return
    end

    -- 璁剧疆浜戠鍔犺浇涓爣蹇? 闃叉 SaveAll 鍦ㄦ鏈熼棿瑕嗙洊浜戠鏁版嵁
    S.cloudLoadPending = true
    S.pendingSaveCallback = nil
    print("[CloudManager] 寮€濮嬩簯绔姞杞? 宸查攣瀹氫簯绔啓鍏?)

    -- BatchGet 鎵€鏈?domain + 鏃ф牸寮弅ey + 鍝堝笇鏍￠獙
    local batchGet = CloudAPI:BatchGet()
    for _, key in pairs(DOMAINS) do
        batchGet:Key(key)
    end
    batchGet:Key(KEYS.legacy_save)
    batchGet:Key(KEYS.save_hash)

    batchGet:Fetch({
        ok = function(values, iscores)
            -- 妫€鏌ヤ簯绔槸鍚︽湁鏂版牸寮忔暟鎹?
            local cloudHasMulti = values[DOMAINS.core] ~= nil
            local cloudHasLegacy = values[KEYS.legacy_save] ~= nil

            if not cloudHasMulti and not cloudHasLegacy then
                -- 浜戠鏃犲瓨妗? 涓婁紶鏈湴
                S.cloudLoadPending = false
                print("[CloudManager] 浜戠鍔犺浇瀹屾垚(鏃犱簯绔瓨妗?, 宸茶В閿佷簯绔啓鍏?)
                if localData then
                    print("[CloudManager] 浜戠鏃犲瓨妗? 涓婁紶鏈湴")
                    CloudManager.SaveAll()
                end
                if callback then callback(localData and "local" or "none") end
                return
            end

            -- 鑾峰彇浜戠鏃堕棿鎴?
            local cloudTime = 0
            if cloudHasMulti then
                local coreData = values[DOMAINS.core]
                cloudTime = (coreData and coreData.savedAt) or 0
            elseif cloudHasLegacy then
                local legData = values[KEYS.legacy_save]
                cloudTime = (legData and legData.savedAt) or 0
            end

            -- 鑾峰彇鏈湴鏃堕棿鎴?
            local localTime = 0
            if localData then
                if localVersion == "multi" and localData.domains and localData.domains.core then
                    localTime = localData.domains.core.savedAt or 0
                elseif localData.savedAt then
                    localTime = localData.savedAt
                end
            end

            -- 瀵规瘮鍐崇瓥
            -- 鍏抽敭鏁版嵁璇婃柇: 鍦ㄥ喅绛栧墠璁板綍鏈湴鍜屼簯绔殑鍏电/铏庣鍊?
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
            print(string.format("[CloudManager] 鏁版嵁瀵规瘮: 鏈湴jade=%s sealCount=%d | 浜戠jade=%s sealCount=%d",
                tostring(localJade), localSealCount, tostring(cloudJade), cloudSealCount))

            local useCloud = false
            if not localData then
                useCloud = true
                print("[CloudManager] 鏈湴鏃犲瓨妗? 浣跨敤浜戠")
            elseif cloudTime > 0 and localTime > 0 then
                useCloud = cloudTime > localTime
                print(string.format("[CloudManager] 鏈湴time=%d vs 浜戠time=%d -> %s",
                    localTime, cloudTime, useCloud and "鐢ㄤ簯绔? or "鐢ㄦ湰鍦?))
            end

            if useCloud then
                if cloudHasMulti then
                    -- 鏂版牸寮? 鎸塪omain鎭㈠
                    local cloudDomains = {}
                    for name, key in pairs(DOMAINS) do
                        cloudDomains[name] = values[key]
                    end
                    -- 鍝堝笇鏍￠獙: 楠岃瘉浜戠瀛樻。瀹屾暣鎬?
                    local storedHashData = values[KEYS.save_hash]
                    if storedHashData and storedHashData.hash then
                        local recalcHash = CloudManager._computeSaveHash(cloudDomains)
                        if recalcHash ~= storedHashData.hash then
                            print("[CloudManager] 浜戠瀛樻。鍝堝笇鏍￠獙澶辫触! stored="
                                .. tostring(storedHashData.hash) .. " calc=" .. tostring(recalcHash))
                            -- 瀛樻。鍙兘琚鏀? 浠嶇劧鍔犺浇浣嗘爣璁拌鍛?
                            CloudManager._hashMismatch = true
                        else
                            CloudManager._hashMismatch = false
                        end
                    end
                    CloudManager._applyMultiDomain({ domains = cloudDomains })
                    -- 璐熷€奸槻鎶?
                    CloudManager._sanitizeResources()
                    -- 淇濆瓨鍒版湰鍦?
                    CloudManager._saveLocalJSON(nil)
                    print("[CloudManager] 宸插簲鐢ㄤ簯绔domain瀛樻。")
                else
                    -- 鏃ф牸寮?
                    local legData = values[KEYS.legacy_save]
                    if rawget(_G, "ApplySaveData") then
                        ApplySaveData(legData)
                    end
                    CloudManager._saveLocalJSON(nil)
                    print("[CloudManager] 宸插簲鐢ㄤ簯绔棫鏍煎紡瀛樻。")
                end
                if callback then callback("cloud") end
            else
                -- 鏈湴鏇存柊, 鍚屾鍒颁簯绔?
                CloudManager.SaveAll()
                if callback then callback("local") end
            end

            -- 瑙ｉ攣浜戠鍐欏叆
            S.cloudLoadPending = false
            print("[CloudManager] 浜戠鍔犺浇瀹屾垚, 宸茶В閿佷簯绔啓鍏?)

            -- 濡傛灉鍔犺浇鏈熼棿鏈夊欢杩熺殑淇濆瓨璇锋眰, 鐜板湪鎵ц涓€娆″畬鏁?SaveAll
            if S.pendingSaveCallback then
                local cb = S.pendingSaveCallback
                S.pendingSaveCallback = nil
                print("[CloudManager] 鎵ц寤惰繜淇濆瓨璇锋眰")
                CloudManager.SaveAll(cb, true) -- forceBypass=true 璺宠繃鍐峰嵈
            end

            -- 濂藉弸/闃佃惀淇＄: 鎷夊彇鍑虹珯鏁版嵁 (鐢宠姹犳ā寮?
            CloudManager._loadMyOutbox()
        end,
        error = function(code, reason)
            print("[CloudManager] 浜戠鍔犺浇澶辫触: " .. tostring(reason))
            -- 瑙ｉ攣浜戠鍐欏叆 (鍗充娇澶辫触涔熻瑙ｉ攣, 鍚﹀垯姘歌繙鏃犳硶淇濆瓨鍒颁簯绔?
            S.cloudLoadPending = false
            print("[CloudManager] 浜戠鍔犺浇澶辫触, 宸茶В閿佷簯绔啓鍏?)
            -- 鎵ц寤惰繜淇濆瓨
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
-- 瀵煎嚭甯搁噺/宸ュ叿鍑芥暟渚涘瓙妯″潡浣跨敤 (瀛愭ā鍧楅€氳繃 CloudManager._C 璁块棶)
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

