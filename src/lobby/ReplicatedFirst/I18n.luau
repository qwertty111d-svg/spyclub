-- Bootstrap copy for ReplicatedFirst. Keep this module dependency-free.
local I18n={}

I18n.Strings={
    loadingClub={"SPY CLUB", "SPY CLUB", "SPY CLUB"},
    loadingEyebrow={"ЗАКРЫТЫЙ НОЧНОЙ КЛУБ", "PRIVATE NIGHT CLUB", "私人夜间俱乐部"},
    loadingDossier={"ДОСЬЕ АГЕНТА", "AGENT DOSSIER", "特工档案"},
    loadingAccess={"ПРОТОКОЛ ДОПУСКА", "ACCESS PROTOCOL", "准入协议"},
    loadingEnter={"Открываем двери…", "Opening the doors…", "正在开门…"},
    loadingCheckDossier={"ПРОВЕРЯЕМ ДОСЬЕ", "CHECKING DOSSIER", "核对档案"},
    loadingSyncProfile={"СИНХРОНИЗИРУЕМ ПРОФИЛЬ", "SYNCING PROFILE", "同步玩家资料"},
    loadingOpenClub={"ОТКРЫВАЕМ КЛУБ", "OPENING THE CLUB", "开启俱乐部"},
    loadingGranted={"ДОПУСК РАЗРЕШЁН", "ACCESS GRANTED", "准入已通过"},
    loadingSlow={"ПОДКЛЮЧЕНИЕ ЗАНИМАЕТ БОЛЬШЕ ВРЕМЕНИ", "CONNECTION IS TAKING LONGER", "连接需要更多时间"},
    loadingContinue={"ОСМОТРЕТЬ КЛУБ", "LOOK AROUND", "参观俱乐部"},
    loadingWaiting={"СОЕДИНЕНИЕ С КЛУБОМ…", "CONNECTING TO THE CLUB…", "连接俱乐部…"},
    loadingHint={"Можно осмотреть лобби, пока профиль подключается.", "You can look around while your profile connects.", "玩家资料连接期间，你可以先参观大厅。"},
}

function I18n.t(language,key)
    local pair=I18n.Strings[key]
    return pair and pair[language=="zh" and 3 or language=="en" and 2 or 1] or key
end

return I18n

