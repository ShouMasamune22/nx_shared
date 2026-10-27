--[[
    nx_shared / shared/config.lua
    Cross-system configuration only. System-specific tuning lives in the
    config.lua of the resource that owns that system.
]]

NX = NX or {}

NX.Config = {
    -- Identity ---------------------------------------------------------------
    Brand = {
        name = 'NOVARA CITY',
        suffix = 'ROLEPLAY',
        tagline = 'Kota yang menulis ceritanya sendiri.',
        version = '0.1.0',
        discord = 'https://discord.gg/novaracity',
        website = 'https://novaracity.example',
        support = 'support@novaracity.example',
        -- Shown on the loading screen and the pause menu.
        socials = {
            { label = 'Discord', value = 'discord.gg/novaracity', icon = 'discord' },
            { label = 'Website', value = 'novaracity.example', icon = 'globe' },
            { label = 'Support', value = 'support@novaracity.example', icon = 'lifebuoy' },
        },
    },

    -- Localization -----------------------------------------------------------
    Locale = {
        default = 'id',   -- Indonesian is the primary language for this server.
        fallback = 'en',
        available = { 'id', 'en' },
    },

    -- Logging ----------------------------------------------------------------
    Log = {
        enabled = true,
        level = 'info',        -- debug | info | warn | error
        echoToConsole = true,  -- prints to the server/client console
        persist = true,        -- writes to the nx_log table
        persistLevel = 'warn', -- minimum level persisted to the database
        maxMessageLength = 900,
    },

    -- UI ---------------------------------------------------------------------
    UI = {
        theme = 'novara-dark',
        -- Shared animation duration used by the design system, in ms.
        transitionMs = 180,
        -- NUI resources must release focus on resource stop. This is the
        -- hard timeout (ms) after which the focus manager force-releases.
        -- Deliberately generous: a player reading the character screen or the
        -- rules panel is legitimately idle, and a short timeout used to steal
        -- the cursor mid-selection.
        focusWatchdogMs = 180000,

        -- Single source of truth for player-toggleable HUD elements.
        -- nx_hud renders them. With the custom pause menu removed there is
        -- no UI exposing them right now; they default to on.
        toggles = {
            { key = 'hud.needs',   label = 'Lapar & haus', default = true },
            { key = 'hud.stamina', label = 'Stamina', default = true },
            { key = 'hud.speed',   label = 'Speedometer', default = true },
            { key = 'hud.fuel',    label = 'Bahan bakar', default = true },
        },
    },

    -- Public content shown on the loading screen and the pause menu.
    -- One source of truth so both surfaces always agree.
    Content = {
        intro = 'Kota yang hidup dari cerita warganya. Setiap jalan, setiap transaksi, setiap keputusan meninggalkan jejak.',
        rules = {
            'Bermain sesuai karakter (in-character) setiap saat di dalam kota.',
            'Dilarang powergaming, metagaming, dan combat logging.',
            'Hormati pemain lain. Konflik tetap di dalam roleplay, bukan di luar.',
            'Nilai nyawa karaktermu. Tidak ada bunuh diri atau bunuh massal tanpa alasan cerita.',
            'Gunakan bahasa Indonesia yang jelas di dalam roleplay.',
            'Laporkan bug dan eksploit ke staff, jangan disalahgunakan.',
        },
        tips = {
            'Tekan B untuk memasang sabuk pengaman sebelum berkendara cepat.',
            'Cek ponsel untuk lowongan pekerjaan dan pesanan pengiriman.',
            'Simpan uang di bank — tunai bisa hilang jika kamu dirampok.',
            'Hubungi EMS lewat ponsel jika kamu terluka parah di jalan.',
            'Bisnis yang dikelola warga menciptakan lapangan kerja nyata di kota.',
            'Reputasi membuka pekerjaan dan kontrak yang lebih menguntungkan.',
        },
    },

    -- Notifications ----------------------------------------------------------
    Notify = {
        position = 'top-right',      -- top-right | top-left | bottom-right | bottom-left | top-center
        defaultDuration = 5000,
        maxVisible = 5,
        maxQueue = 40,
        duplicateWindowMs = 1200,    -- identical payloads inside this window are suppressed
        sound = true,
        volume = 0.35,
    },

    -- Time / economy helpers -------------------------------------------------
    Economy = {
        currency = '$',
        currencyPosition = 'prefix',
        -- Money types that must never be displayed from client-authoritative data.
        authoritativeTypes = { 'cash', 'bank', 'crypto' },
    },
}

--[[
    Feature switches. A disabled feature must also be removed from the
    server.cfg startup order; these flags only gate runtime behaviour so a
    half-configured system never half-runs.
]]
NX.Features = {
    customLoading = true,
    customHud = true,
    customScoreboard = true,
    customPause = true,
    customNotify = true,
    customCharacter = false,  -- exo-multicharacter owns selection + creation (nx_character retired)
    customSpawn = false,      -- exo-multicharacter owns the arrival selector (nx_spawn retired)
    customInteraction = false,
    customInventory = false,
}
