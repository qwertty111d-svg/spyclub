-- Authored club text, not generated during play. Competitive secrets stay on the server.
local Files={Ids={'cassette','envelope','call'}}
local words={
 vincent_welcome={'Садись ближе. У меня осталось несколько незакрытых дел. Какое посмотрим?','Come closer. I have a few unfinished cases. Which one shall we look at?','坐近些。我还有几件未结的案子。先看哪件？'},
 question_evidence={'Какие у нас есть улики?','What evidence do we have?','我们有哪些证据？'},
 question_testimony={'Что рассказали гости?','What did the guests say?','客人们说了什么？'},
 question_accuse={'Кажется, я знаю, кто врёт.','I think I know who is lying.','我想我知道谁在撒谎。'},
 ask_evidence={'Что проверим сначала? Запись, телефонный журнал или папку?','What shall we check first: the tape, the phone log, or the folder?','先查录音、电话记录，还是文件夹？'},
 ask_testimony={'Я сохранил их показания. Чей рассказ хочешь услышать?','I kept their statements. Whose account would you like to hear?','我保留了他们的陈述。你想听谁的？'},
 testimony_record={'Запись показаний','Recorded statement','陈述记录'},
 choose_accused={'Назови имя. Прежде чем закрыть дело, ещё раз сверим показания.','Give me a name. We will check the statement once more before closing the case.','说个名字。结案前，我们再核对一次陈述。'},
 confirm_accusation={'Закрываем дело с этим обвинением?','Close the case with this accusation?','按此指控结案？'},
 return_cases={'Посмотрим другое дело.','Let us look at another case.','看看另一个案子。'},
 review_evidence={'Ещё раз сверим улики.','Let us review the evidence.','再核对一下证据。'},
 scene_view={'Сцена','Scene','场景'},notebook_view={'Записи','Notebook','笔记'},scene_overview={'Общий план','Overview','全景'},
 vincent={'Винсент','Vincent','文森特'},scene_hint={'Выбери предмет или собеседника.','Choose an object or a person.','选择物品或人物。'},
 interview={'Поговорить','Interview','交谈'},accuse={'Обвинить','Accuse','指控'},clue_progress={'Осмотрено улик','Clues examined','已检查线索'},
 choose_suspect={'Выбери собеседника, чтобы сравнить его слова с уликами.','Choose a person to compare their story with the evidence.','选择人物，将其陈述与证据比较。'},
 scene_unavailable={'Сцена недоступна. Расследование можно продолжить по записям.','The scene is unavailable. You can continue with the notebook.','场景暂不可用，可继续查看笔记。'},
 unexamined={'Улика ещё не изучена.','This clue has not been examined yet.','尚未检查此线索。'},
 archive={'Архив клуба','Club archive','俱乐部档案'},training={'Разговор с Винсентом','A word with Vincent','与文森特交谈'},
 quick={'Играть','Play','开始游戏'},classic={'Классика','Classic','经典模式'},meeting={'Тайная встреча','Secret meeting','秘密会面'},
 inspect_action={'Осмотреть','Inspect','检查'},open_archive={'Открыть','Open','打开'},tape={'Магнитофон','Tape recorder','录音机'},phone={'Телефон','Telephone','电话'},folder={'Папка','Folder','文件夹'},
 defense={'Последнее слово','Last word','最后陈述'},clues={'Улики и алиби','Clues & alibi','线索与不在场证明'},notes={'Заметки за столом','Table notes','桌边笔记'},
 waiting={'Ищем компанию…','Finding players…','正在寻找玩家…'},preparing={'Стол найден. Готовимся к встрече…','Table found. Getting ready…','已找到桌子，正在准备…'},matched={'Переходим за стол…','Joining the table…','正在加入桌子…'},
 unavailable={'Поиск сейчас недоступен. Можно выбрать стол или зайти в телефон.','Search is unavailable. Choose a table or open your phone.','暂时无法匹配。可选择桌子或打开案件。'},
 cancel={'Отменить поиск','Cancel search','取消匹配'},manual={'Найти / создать стол','Find / create table','查找／创建桌子'},solo={'Дела в телефоне','Cases on your phone','手机案件'},
 close={'Закрыть','Close','关闭'},back={'Назад','Back','返回'},choose={'Выбрать','Choose','选择'},review={'Разбор дела','Case review','案件解析'},saved={'Дело закрыто','Case closed','案件已结'},
 intro={'У каждого есть секрет','Everyone has a secret','每个人都有秘密'},accesscode={'Код доступа','Access code','访问密码'},codeAttempt={'Назвать код','Guess the code','猜测密码'},
 card={'Открой свою карточку','Open your card','打开你的卡片'},inspect={'Выбери одну улику на столе','Choose one clue on the table','选择桌上的一条线索'},testify={'Расскажи об улике, сохрани свой секрет','Share your clue; keep your secret','分享线索，保守秘密'},
 discuss={'Сопоставь показания и выбери подозреваемого','Compare stories and choose a suspect','比较陈述并选择嫌疑人'},vote={'Проголосуй за подозреваемого','Vote for a suspect','投票选择嫌疑人'},
 your_defense={'Тебе дали последнее слово','You have the last word','现在由你最后陈述'},listen_defense={'Слушай последнее слово подозреваемого','Listen to the suspect’s last word','听嫌疑人的最后陈述'},
 hint={'Дай подсказку, понятную своим','Give a clue others will recognise','给出同伴能理解的提示'},hint_wait={'Слушай подсказку и сравни со своим словом','Listen and compare with your word','听提示并与你的词比较'},
 spy_goal={'Скрой свою роль. Слушай улики: три фрагмента складываются в код.','Keep your cover. Three clue fragments make the access code.','隐藏身份。三条线索的片段组成密码。'},
 spy_secret={'У тебя нет настоящего алиби. Убедись, что твою историю нельзя опровергнуть.','Your alibi is a cover story. Make it hold up.','你的不在场证明是编造的。让故事经得起推敲。'},
 alibi_1={'Ты проверял приглашения у входа. Своего гостя ты видел до начала встречи.','You checked invitations at the entrance and saw your guest before the meeting.','你在入口检查邀请函，会面前见过自己的客人。'},
 alibi_2={'Ты был у бара. Винсент отвлёкся на телефон, и ты подождал.','You were at the bar. Vincent answered the phone while you waited.','你在吧台，文森特接电话时你在等候。'},
 alibi_3={'Ты осматривал архив. Корешки папок были на своих местах.','You checked the archive. The folders were in their usual places.','你检查了档案，文件夹都在原位。'},
 alibi_4={'Ты ждал в гостиной. Из коридора доносился шум дождя.','You waited in the lounge and heard rain from the corridor.','你在休息室等候，听到走廊外的雨声。'},
 secret_1={'Ты пришёл без приглашения и не хочешь об этом говорить.','You arrived without an invitation and would rather keep it quiet.','你没有邀请函，不想让人知道。'},
 secret_2={'Ты должен Винсенту за прошлый вечер. Это не делает тебя шпионом.','You still owe Vincent for last night. That does not make you the spy.','你还欠文森特昨晚的钱，但这不代表你是间谍。'},
 secret_3={'Ты уже открывал чужую папку из любопытства.','You once opened someone else’s folder out of curiosity.','你曾因好奇打开别人的文件夹。'},
 secret_4={'Ты знаешь одного гостя, но обещал не выдавать знакомство.','You know one guest but promised to keep that connection quiet.','你认识一位客人，但答应保密。'},
 source_taken={'Эту улику уже изучают. Выбери другую.','Someone is examining this clue. Choose another.','有人正在检查这条线索，请选择另一条。'},
 inspect_first={'Сначала изучи все три источника.','Examine all three sources first.','先检查全部三个来源。'},wrong={'Показания пока не сходятся. Сравни улики ещё раз.','That story does not fit. Compare the clues again.','陈述还不吻合，请再次比较线索。'},
 save_failed={'Не удалось сохранить. Повтори ответ — дело останется открытым.','Could not save. Try the answer again; your case remains open.','无法保存。请重试答案，案件仍然保留。'},
 stale={'Это дело уже закрыто или заменено. Открой его заново.','This case was closed or replaced. Open it again.','案件已关闭或更换，请重新打开。'},busy={'Сначала закончи текущее действие.','Finish your current action first.','请先完成当前操作。'},
 timeout={'Ответ задержался. Попробуй ещё раз.','The response took too long. Try again.','响应超时，请重试。'},not_member={'Ты не участник этой встречи.','You are not part of this meeting.','你不是本次会面的参与者。'},
 own={'Это только твоя улика','This clue is yours only','这条线索仅属于你'},nominate={'Кого подозреваешь?','Who do you suspect?','你怀疑谁？'},
 help={'Подсказки','Guidance','帮助'},help_off={'Скрыть подсказки','Hide guidance','隐藏提示'},
 solo_note={'Одиночное дело · прогресс архива','Solo case · archive progress','单人案件 · 档案进度'},tutorial_note={'Обучение · без обычных побед и XP','Training · no regular wins or XP','教学 · 不增加普通胜场或经验'},
 training_1={'Винсент: «Сначала посмотри свою карточку. Она не для соседей».','Vincent: “Read your card first. Keep it to yourself.”','文森特：“先看自己的卡片，别让旁人看到。”'},
 training_2={'Слово — «аэропорт». Как дать подсказку и не выдать его шпиону?','Your word is “airport”. Give a useful clue without naming it.','你的词是“机场”。给出有用提示，但别直接说出来。'},
 training_3={'Нина: «Очередь». Хьюго: «Табло». Феликс: «Морские волны». Кто выбивается?','Nina: “Queue.” Hugo: “Departure board.” Felix: “Ocean waves.” Who does not fit?','妮娜：“排队。”雨果：“航班显示屏。”费利克斯：“海浪。”谁不合适？'},
 training_4={'Первые подозрения не заменяют обсуждение. Что сделать до голосования?','A first suspicion is not a verdict. What comes before voting?','初步怀疑不等于结论。投票前应做什么？'},
 training_5={'Шпион тоже может выиграть: слушать подсказки и один раз назвать точное слово. В тайной встрече он собирает код.','The spy can win too: listen and make one exact guess. In a secret meeting, gather the code.','间谍也能赢：听提示并进行一次准确猜测。秘密会面中需要收集密码。'},
 open={'Открыть карточку','Open the card','打开卡片'},subtle={'Проверка документов','Document check','证件检查'},literal={'Аэропорт','Airport','机场'},irrelevant={'Красная роза','Red rose','红玫瑰'},
 listen={'Сравнить и обсудить','Compare and discuss','比较并讨论'},rush={'Сразу обвинить','Accuse immediately','立即指控'},code={'Одна точная попытка','One exact attempt','一次准确猜测'},spam={'Бесконечно угадывать','Keep guessing forever','不断猜测'},
 training_done={'Винсент: «Теперь садись за настоящий стол. Слушай людей — не только своё слово».','Vincent: “Now join a real table. Listen to the people, not just your own word.”','文森特：“现在加入真正的桌子。要听别人说什么，别只顾自己的词。”'},
 innocent={'Твоё алиби','Your alibi','你的不在场证明'},secret={'Твой секрет','Your secret','你的秘密'},evidence={'Твоя улика','Your clue','你的线索'},
 code_pair={'Фрагмент кода','Code fragment','密码片段'},until_result={'Полный разбор откроется после голосования.','The full review opens after the vote.','完整解析将在投票后显示。'},
 code_order={'Порядок кода: магнитофон → телефон → папка. Каждый источник даёт две цифры.','Code order: tape recorder → telephone → folder. Each source gives two digits.','密码顺序：录音机 → 电话 → 文件夹。每个来源提供两位数字。'},
 no_company={'Нет компании? Пока ищем игроков, можно открыть одиночное дело.','Here alone? Open a solo case while we search.','独自来玩？匹配时可以打开单人案件。'},
 players={'Игроков в поиске','Players searching','匹配中的玩家'},closed={'Выйти из поиска','Leave search','退出匹配'},
 meeting_brief={'Из клуба исчезла копия секретного дела. У каждого есть алиби и причина промолчать. Только один гость работает под прикрытием.','A copy of a secret file is missing. Everyone has an alibi and a reason to stay quiet. One guest is undercover.','一份秘密文件副本不见了。每个人都有不在场证明和隐瞒的理由，其中一位客人是卧底。'},
 tape_clue={'На записи слышны два голоса у закрытого архива: %s и %s.','The archive recording contains two voices: %s and %s.','档案室录音中有两个声音：%s和%s。'},
 phone_clue={'Телефонный журнал связывает подозрительный звонок с двумя гостями: %s и %s.','The call log narrows the suspicious call to two guests: %s and %s.','通话记录将可疑电话关联到两位客人：%s和%s。'},
 folder_clue={'На листе доступа отмечены два гостя: %s и %s. Один из них внёс ложную запись.','The access sheet names %s and %s. One of them forged the entry.','访问记录上有%s和%s，其中一人伪造了记录。'},
 conclusion={'Шпион — %s. Найдите имя, которое повторяется в разных уликах. Код: %s.','The spy was %s. Compare the name shared by different clues. Code: %s.','间谍是%s。比较不同线索中重复出现的名字。密码：%s。'},
 invalid={'Проверь выбранное действие.','Check the selected action.','请检查所选操作。'},already_inspected={'У тебя уже есть личная улика.','You already have your personal clue.','你已经拥有个人线索。'},
 classic_brief={'Одно слово, один шпион. Давайте подсказки и сравнивайте ответы.','One word, one spy. Give clues and compare answers.','一个词，一名间谍。给出提示并比较回答。'},
 meeting_brief_short={'Личные алиби, улики на столе и последнее слово подозреваемого.','Private alibis, table clues and a suspect’s last word.','个人不在场证明、桌上线索及嫌疑人的最后陈述。'},
 join={'Найти компанию','Find players','寻找玩家'},mode={'Как играем?','Choose a mode','选择模式'},hint_seconds={'Ход','Turn','回合'},
 quick_caption={'Стол на 3–4 игроков','A table for 3–4 players','3至4人桌'},manual_busy={'Поиск ещё завершается. Повтори отмену через пару секунд.','Search is still closing. Try cancelling again in a moment.','匹配正在结束，请稍后再次取消。'},
 one_attempt={'Шесть цифр. Одна попытка за матч.','Six digits. One attempt per match.','六位数字，每局一次机会。'},
 inspect_stage={'Осмотр улик','Examine the clues','检查线索'},discuss_stage={'Обсуждение','Discussion','讨论'},testify_stage={'Показания','Testimony','陈述'},
 finished_stage={'Дело закрыто','Case closed','案件已结'},someone_defense={'Сейчас говорит %s','%s has the floor','现在由%s陈述'},
}
local function index(lang)return lang=='en'and 2 or lang=='zh'and 3 or 1 end
local function tr(v,lang)return v[index(lang)]or v[1]end
function Files.text(lang,key)local v=words[key];return v and tr(v,lang)or key end
local names={felix={'Феликс','Felix','费利克斯'},nina={'Нина','Nina','妮娜'},hugo={'Хьюго','Hugo','雨果'}}
function Files.name(lang,id)return tr(names[id]or{id,id,id},lang)end
local cases={
 cassette={title={'Последняя кассета','The last cassette','最后一盘磁带'},brief={'Кто-то пытался стереть запись закрытой встречи. Три гостя оставили показания. Найди рассказ, который противоречит самой записи.','Someone tried to erase a private meeting. Find the guest whose account contradicts the recording.','有人试图删除秘密会面录音。找出陈述与录音矛盾的客人。'},
  statements={felix={'В 22:05 я открыл крышку и чистил головку магнитофона.','At 22:05 I opened the lid to clean the recorder head.','22:05我打开机盖清洁录音头。'},nina={'В 22:08 из бара донёсся звонок телефона.','At 22:08 I heard the bar telephone ring.','22:08我听到吧台电话响了。'},hugo={'В 22:10 я закрыл кассу. Это слышно на записи.','At 22:10 I closed the till. You can hear it on tape.','22:10我关闭收银机，录音里能听到。'}},
  sources={tape={'Запись с 22:00 до 22:15 непрерывна: звонок в 22:08, касса в 22:10.','The tape runs continuously from 22:00 to 22:15: a call at 22:08 and the till at 22:10.','22:00至22:15录音连续：22:08电话，22:10收银机。'},phone={'Журнал: входящий звонок в бар в 22:08. Часы телефона совпадают с часами клуба.','Log: the bar received a call at 22:08. The phone clock matches the club clock.','记录：吧台22:08接到来电，电话时钟与俱乐部一致。'},folder={'Инструкция: открытие крышки мгновенно отключает запись. Время всех показаний проверено.','Manual: opening the lid stops recording immediately. The times in all statements were checked.','说明书：打开机盖会立即停止录音。全部陈述时间已经核实。'}},
  solution={'Феликс. При открытии крышки запись остановилась бы, но она непрерывна. Звонок и касса подтверждают время остальных гостей.','Felix. Opening the lid would have stopped the uninterrupted tape. The call and till confirm the other accounts.','费利克斯。打开机盖会停止录音，但磁带连续。电话和收银机声确认了其他人的陈述。'}},
 envelope={title={'Пустой конверт','The empty envelope','空信封'},brief={'Из запечатанного конверта исчезла схема. Никто не должен был видеть её оборот. Кто сообщил деталь, которой не мог знать?','A plan vanished from a sealed envelope. Nobody should have seen its reverse. Who revealed something they could not know?','密封信封中的图纸不见了。谁透露了本不该知道的背面细节？'},
  statements={felix={'Я видел только синий конверт на стойке.','I only saw the blue envelope on the counter.','我只看到柜台上的蓝色信封。'},nina={'На конверте была неповреждённая печать.','The envelope seal was intact.','信封封印完好。'},hugo={'Я ничего не открывал. На обороте схемы зелёная метка.','I opened nothing. The back of the plan has a green mark.','我什么都没打开，图纸背面有绿色标记。'}},
  sources={tape={'Винсент на записи: «Отправлю схему лицевой стороной вверх; об обороте никому не говорил».','Vincent on tape: “I packed the plan face up. I told nobody about its reverse.”','录音中的文森特：“我把图纸正面朝上放好，从没说过背面的事。”'},phone={'Секретарь подтвердил: фотографии схемы не отправлялись, описания оборота нет.','The secretary confirms no photos were sent and the reverse was never described.','秘书确认未发送照片，也未描述背面。'},folder={'Опись: конверт непрозрачный. Зелёная метка действительно стоит на скрытом обороте.','Inventory: the envelope is opaque. A green mark is on the hidden reverse.','清单：信封不透明，隐藏的背面确实有绿色标记。'}},
  solution={'Хьюго. Он назвал зелёную метку на скрытом обороте. Через конверт её не видно, а Винсент никому о ней не говорил.','Hugo. He knew the hidden green mark, invisible through the envelope and never mentioned by Vincent.','雨果。他知道隐藏的绿色标记，信封不透明，文森特也没提过。'}},
 call={title={'Звонок после полуночи','The midnight call','午夜电话'},brief={'Служебным телефоном передали код за пределы клуба. Кто врёт о том, откуда разговаривал?','A club phone leaked a code. Who lied about where they called from?','有人用俱乐部电话泄露密码。谁谎报了通话地点？'},
  statements={felix={'В 00:12 я звонил из гостиной с беспроводной трубки.','At 00:12 I called from the lounge with a cordless handset.','00:12我用无线电话从休息室打电话。'},nina={'После полуночи я ждала у двери гостиной.','After midnight I waited by the lounge door.','午夜后我在休息室门口等候。'},hugo={'В 00:12 я относил стаканы на кухню.','At 00:12 I carried glasses to the kitchen.','00:12我把杯子送到厨房。'}},
  sources={tape={'Фоновая запись: в 00:12 у стойки слышен голос Феликса и щелчок телефонного диска.','Background tape: Felix’s voice and the telephone dial can be heard at the bar at 00:12.','背景录音：00:12吧台传来费利克斯的声音和电话转盘声。'},phone={'Аппарат проводной, закреплён на стойке. Шнур не достаёт до гостиной. Беспроводных трубок в клубе нет.','The wired phone is fixed to the bar. Its cable cannot reach the lounge. The club has no cordless handsets.','电话有线并固定在吧台，线长不到休息室，俱乐部没有无线电话。'},folder={'Журнал звонков: код передан именно с этого аппарата в 00:12. Вызова из гостиной не было.','Call log: this exact phone sent the code at 00:12. No call came from the lounge.','记录：此电话于00:12泄露密码，休息室没有拨出电话。'}},
  solution={'Феликс. Код передали с закреплённого проводного аппарата у бара. История о беспроводной трубке в гостиной невозможна.','Felix. The fixed bar phone sent the code. His story about a cordless lounge handset is impossible.','费利克斯。密码由固定在吧台的有线电话泄露，他所说的休息室无线电话不存在。'}},
}
function Files.valid(id)return type(id)=='string'and cases[id]~=nil end
function Files.public(id,lang)
 local c=cases[id];if not c then return nil end
 local out={id=id,title=tr(c.title,lang),brief=tr(c.brief,lang),sources={},suspects={}}
 for _,source in ipairs({'tape','phone','folder'})do out.sources[#out.sources+1]={id=source,label=Files.text(lang,source)}end
 for _,person in ipairs({'felix','nina','hugo'})do out.suspects[#out.suspects+1]={id=person,name=Files.name(lang,person),statement=tr(c.statements[person],lang)}end
 return out
end
function Files.evidence(id,source,lang)local c=cases[id];return c and c.sources[source]and tr(c.sources[source],lang)end
function Files.explanation(id,lang)local c=cases[id];return c and tr(c.solution,lang)end
function Files.training(step,lang)
 local choices={{'open'},{'subtle','literal','irrelevant'},{'felix','nina','hugo'},{'listen','rush'},{'code','spam'}}
 local list={};for _,id in ipairs(choices[step]or{})do list[#list+1]={id=id,label=names[id]and Files.name(lang,id)or Files.text(lang,id)}end
 return {brief=Files.text(lang,'training_'..step),choices=list,step=step,total=5}
end
return Files
