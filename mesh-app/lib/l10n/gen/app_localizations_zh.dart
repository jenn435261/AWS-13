// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Mesh';

  @override
  String get navMap => '地图';

  @override
  String get navMessages => '消息';

  @override
  String get navMore => '更多';

  @override
  String get helpButton => '求助';

  @override
  String get helpButtonSemantics => '请求帮助';

  @override
  String get helpButtonHint => '轻点查看选项。按住 2 秒发送 SOS。';

  @override
  String get helpMenuTitle => '你想做什么？';

  @override
  String get needHelp => '我需要帮助';

  @override
  String get needHelpSub => '告诉附近的人你需要什么';

  @override
  String get canHelp => '我可以帮忙';

  @override
  String get canHelpSub => '让附近的人知道你能提供什么';

  @override
  String get sosTip => '有危险？按住红色求助按钮，立即发送 SOS。';

  @override
  String get holdForSos => '按住发送 SOS';

  @override
  String get holdForSosSub => '立即发送你的位置';

  @override
  String get keepHolding => '继续按住以发送 SOS';

  @override
  String get sosSent => '已发送 SOS 和你的位置';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get dismiss => '关闭';

  @override
  String get next => '下一步';

  @override
  String get close => '关闭';

  @override
  String get edit => '修改';

  @override
  String get view => '查看';

  @override
  String get send => '发送';

  @override
  String radiosNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '附近有 $count 个电台',
      zero: '附近没有电台',
    );
    return '$_temp0';
  }

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get layers => '图层';

  @override
  String get layerRequests => '求助请求';

  @override
  String get layerRadios => '电台和覆盖范围';

  @override
  String get myLocation => '显示我的位置';

  @override
  String get language => '语言';

  @override
  String get nothingNearby => '附近暂时没有内容';

  @override
  String distanceMeters(int meters) {
    return '距离 $meters 米';
  }

  @override
  String distanceKm(String km) {
    return '距离 $km 公里';
  }

  @override
  String get howItTravels => '你的求助如何传送';

  @override
  String get travelPhone => '这部手机';

  @override
  String get travelPhoneSub => '先保存所有内容，没有信号也可以';

  @override
  String get travelMesh => '电台网络';

  @override
  String get travelMeshSub => '在电台之间一站一站传递';

  @override
  String get travelCloud => 'AWS';

  @override
  String get travelCloudOnline => '检查并保存一份副本';

  @override
  String get travelCloudOffline => '暂时无法连接。你的求助在电台网络中等待。';

  @override
  String get travelHelpers => '救助者';

  @override
  String get travelHelpersSub => '看到你的求助并回复';

  @override
  String get showOnMap => '在地图上查看';

  @override
  String get openDetails => '查看详情';

  @override
  String get kindMedical => '医疗救助';

  @override
  String get kindMedicalSub => '受伤、生病或被困';

  @override
  String get kindWater => '饮用水';

  @override
  String get kindWaterSub => '干净的饮用水';

  @override
  String get kindShelter => '住处';

  @override
  String get kindShelterSub => '一个安全的地方';

  @override
  String get kindPower => '电力';

  @override
  String get kindPowerSub => '为手机或医疗设备充电';

  @override
  String get kindOther => '其他';

  @override
  String get kindOtherSub => '在下一步中说明';

  @override
  String get kindSos => 'SOS';

  @override
  String get urgencyNow => '现在就要';

  @override
  String get urgencyNowSub => '生命或安全有危险';

  @override
  String get urgencySoon => '几小时内';

  @override
  String get urgencySoonSub => '情况正在变糟';

  @override
  String get urgencyLater => '可以等';

  @override
  String get urgencyLaterSub => '暂时稳定';

  @override
  String get stageSaved => '已保存在这部手机上';

  @override
  String get stageSavedSub => '一有电台在范围内就会发送';

  @override
  String get stageMesh => '已通过电台网络发送';

  @override
  String stageMeshSub(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: '经过了 $hops 个电台',
      zero: '直接到达电台',
    );
    return '$_temp0';
  }

  @override
  String get stageVerified => '服务器已检查';

  @override
  String get stageVerifiedSub => 'AWS 已检查求助并保存副本';

  @override
  String get stageAssigned => '已找到救助者';

  @override
  String stageAssignedSub(String name) {
    return '$name 接受了这个求助';
  }

  @override
  String get stageOnTheWay => '救助者正在路上';

  @override
  String stageOnTheWaySub(String name) {
    return '$name 正在前往';
  }

  @override
  String get stageResolved => '已解决';

  @override
  String get stageResolvedSub => '已标记为完成';

  @override
  String get stageWaiting => '等待中';

  @override
  String stepOf(int step, int total) {
    return '第 $step 步，共 $total 步';
  }

  @override
  String get helpStep1Title => '你需要什么？';

  @override
  String get helpStep2Title => '还有别的吗？';

  @override
  String get urgencyQuestion => '有多紧急？';

  @override
  String get peopleQuestion => '有几个人需要帮助？';

  @override
  String peopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String get fewerPeople => '减少人数';

  @override
  String get morePeople => '增加人数';

  @override
  String get locationTitle => '位置';

  @override
  String locationAuto(int meters) {
    return '已自动共享，误差在 $meters 米内';
  }

  @override
  String get locationMissing => '无法获取你的位置。请描述你在哪里。';

  @override
  String get locationNoteLabel => '描述你在哪里';

  @override
  String get locationNoteHint => '例如：二楼，楼梯旁边';

  @override
  String get noteLabel => '还有别的吗？（可选）';

  @override
  String get sendRequest => '发送求助';

  @override
  String get requestSent => '求助已发送';

  @override
  String get requestDiscarded => '已放弃求助';

  @override
  String get requestCancelled => '求助已取消';

  @override
  String get requestRestored => '求助已恢复';

  @override
  String get cancelRequest => '取消求助';

  @override
  String get problemMissingKind => '请选择你需要什么。';

  @override
  String problemPeople(int max) {
    return '请输入 1 到 $max 之间的人数。';
  }

  @override
  String problemNoteTooLong(int max) {
    return '说明请少于 $max 个字符。';
  }

  @override
  String get problemLocation => '无法获取你的位置，请描述你在哪里。';

  @override
  String get offerStep1Title => '我能提供的物资';

  @override
  String get offerStep2Title => '补充几个信息';

  @override
  String get offerNoteLabel => '给附近的人的说明（可选）';

  @override
  String get offerNoteHint => '例如：我有车，可以坐 4 个人';

  @override
  String get startOffering => '开始提供帮助';

  @override
  String get offeringStarted => '你正在提供帮助';

  @override
  String offeringList(String list) {
    return '你提供：$list';
  }

  @override
  String get stopOffering => '停止';

  @override
  String get offerStopped => '你已停止提供帮助';

  @override
  String get offerPrompt => '你能帮忙吗？让附近的人知道。';

  @override
  String get tabNearMe => '我附近';

  @override
  String get tabMine => '我的';

  @override
  String get iCanHelp => '我来帮忙';

  @override
  String get youAreHelping => '你正在帮忙';

  @override
  String get stopHelping => '不再帮忙';

  @override
  String get acceptedToast => '你正在帮忙。对方知道你要来了。';

  @override
  String get releasedToast => '你已不再帮忙';

  @override
  String get noNearby => '附近没有待处理的求助';

  @override
  String get noMine => '你还没有求助';

  @override
  String fromName(String name) {
    return '来自 $name';
  }

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String hoursAgo(int n) {
    return '$n 小时前';
  }

  @override
  String daysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get progressTitle => '进度';

  @override
  String get detailsTitle => '详情';

  @override
  String get showToResponder => '给救援人员看';

  @override
  String get requestNotFound => '这个求助已不存在。';

  @override
  String get cardNeedHelp => '我需要帮助';

  @override
  String get cardSwipeHint => '左右滑动可以切换语言';

  @override
  String get cardTheirWords => '对方的原话，未翻译：';

  @override
  String get urgencyTitle => '紧急程度';

  @override
  String get peopleTitle => '人数';

  @override
  String get noMessages => '还没有消息';

  @override
  String get messageHint => '消息';

  @override
  String get languageSystem => '跟随手机设置';

  @override
  String get display => '显示与无障碍';

  @override
  String displaySub(int percent) {
    return '文字大小 $percent%';
  }

  @override
  String get theme => '主题';

  @override
  String get themeAuto => '自动';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get textSize => '文字大小';

  @override
  String get highContrast => '高对比度';

  @override
  String get highContrastSub => '颜色和边框更醒目';

  @override
  String get textPreview => '文字会显示成这样。';

  @override
  String get privacy => '隐私与安全';

  @override
  String get phoneLockOn => '应用锁已开启';

  @override
  String get phoneLockOff => '应用锁已关闭';

  @override
  String get phoneLock => '用面容 ID 或指纹锁定';

  @override
  String get phoneLockSub => '失败时使用手机密码';

  @override
  String get phoneLockWeb => '可在 iOS 和 Android 应用中使用';

  @override
  String get phoneLockUnavailable => '请先在这部手机上设置密码或面容 ID';

  @override
  String get lockNow => '立即锁定';

  @override
  String get lockNowSub => '锁定时仍可发送 SOS';

  @override
  String get clearTemp => '清除临时数据';

  @override
  String get clearTempSub => '旧消息和已完成的求助。AWS 会保留副本。';

  @override
  String cleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已清除 $count 项',
      zero: '没有可清除的内容',
    );
    return '$_temp0';
  }

  @override
  String get eraseAll => '清除这部手机上的所有内容';

  @override
  String get eraseAllSub => '按住 3 秒。此操作无法撤销。';

  @override
  String get erased => '已清除这部手机上的所有内容';

  @override
  String get network => '电台网络';

  @override
  String get manage => '管理网络';

  @override
  String get manageSub => '为所有人开启或关闭电台';

  @override
  String get admin => '用户和角色';

  @override
  String get adminSub => '更改谁可以管理网络';

  @override
  String get account => '账号';

  @override
  String signedInAs(String name) {
    return '已登录：$name';
  }

  @override
  String get guestMode => '正在以访客身份使用 Mesh';

  @override
  String get signIn => '登录';

  @override
  String get signInSub => '可选。救助者和管理员需要登录。';

  @override
  String get signOut => '退出登录';

  @override
  String get nameLabel => '姓名';

  @override
  String get roleLabel => '角色';

  @override
  String get roleClient => '成员';

  @override
  String get roleManager => '管理员';

  @override
  String get roleAdmin => '超级管理员';

  @override
  String get demoSignIn => '演示登录。在正式应用中，你的角色由服务器决定。';

  @override
  String get nodeOnline => '在线';

  @override
  String get nodeOffline => '离线';

  @override
  String get hopsDirect => '直连';

  @override
  String hopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 跳',
    );
    return '$_temp0';
  }

  @override
  String get externalPower => '外接电源';

  @override
  String get noNodes => '还没有收到任何电台信号';

  @override
  String get nodeId => 'ID';

  @override
  String get lastHeard => '最近信号';

  @override
  String get battery => '电量';

  @override
  String get signalStrength => '信号强度';

  @override
  String get signalNoise => '信噪比';

  @override
  String get hopsTitle => '跳数';

  @override
  String get manageHint => '你关闭的电台不会显示给成员。';

  @override
  String get loadFailed => '无法加载此页面。';

  @override
  String get lockedTitle => 'Mesh 已锁定';

  @override
  String get lockedSub => '解锁后可查看你的求助和消息。';

  @override
  String get unlock => '解锁';

  @override
  String get unlockReason => '解锁 Mesh';

  @override
  String get unlockWebNote => '网页预览没有面容 ID，所以点解锁会直接打开应用。';

  @override
  String get unlockFailed => '无法解锁。请重试或使用密码。';

  @override
  String alertNearby(String kind) {
    return '附近有新求助：$kind';
  }

  @override
  String alertHelper(String name) {
    return '$name 接受了你的求助';
  }

  @override
  String get navContacts => '联系人';

  @override
  String get kindFood => '食物';

  @override
  String get kindFoodSub => '饭菜或婴儿奶粉';

  @override
  String get kindMedicine => '药品';

  @override
  String get kindMedicineSub => '处方药、胰岛素、吸入器';

  @override
  String get kindTransportation => '交通';

  @override
  String get kindTransportationSub => '需要搭车，或帮忙移动病人';

  @override
  String get kindCommunication => '通讯';

  @override
  String get kindCommunicationSub => '联系家人或呼救';

  @override
  String get noteExampleHint => '例如：需要一个冷藏的地方存放一个人的胰岛素';

  @override
  String get structuredFirst => '你的选择会先发送，信号很弱也能送达。说明会在网络有空间时随后发送。';

  @override
  String suggestion(String kind) {
    return '看起来是：$kind';
  }

  @override
  String get useSuggestion => '使用这个';

  @override
  String get amountQuestion => '你有多少？';

  @override
  String get amountPlenty => '充足';

  @override
  String get amountSome => '一些';

  @override
  String get amountLow => '很少';

  @override
  String get availabilityQuestion => '什么时候可以提供？';

  @override
  String get availabilityNow => '现在';

  @override
  String get availabilityToday => '今天';

  @override
  String get availabilityCustom => '其他时间';

  @override
  String get availabilityNoteLabel => '什么时候？';

  @override
  String get availabilityNoteHint => '例如：晚上 6 点以后';

  @override
  String get transportQuestion => '你能怎么运送？';

  @override
  String get transportWalking => '步行';

  @override
  String get transportBicycle => '自行车';

  @override
  String get transportCar => '汽车';

  @override
  String get transportTruck => '卡车';

  @override
  String get transportVan => '厢式车';

  @override
  String get capacityQuestion => '你能运多少？';

  @override
  String get capacitySmall => '少量';

  @override
  String get capacityMedium => '中等';

  @override
  String get capacityLarge => '大量';

  @override
  String get supplyWater => '饮用水';

  @override
  String get supplyFood => '食物';

  @override
  String get supplyBlankets => '毯子';

  @override
  String get supplyBatteries => '电池';

  @override
  String get supplyCharging => '充电';

  @override
  String get supplyMedicine => '药品';

  @override
  String get supplyTransportation => '交通';

  @override
  String get supplyShelter => '住处';

  @override
  String get supplyTools => '工具';

  @override
  String get supplyOther => '其他';

  @override
  String get problemSupplies => '请至少选择一项。';

  @override
  String get problemTransport => '请选择你的运送方式。';

  @override
  String get resHospital => '医院';

  @override
  String get resPharmacy => '药房';

  @override
  String get resPolice => '警察';

  @override
  String get resFire => '消防站';

  @override
  String get resWater => '饮用水';

  @override
  String get resFood => '食物';

  @override
  String get resShelter => '住处';

  @override
  String get resCharging => '充电';

  @override
  String get resTransportation => '交通';

  @override
  String get resRoadProblem => '道路问题';

  @override
  String get verifiedOrg => '已认证机构';

  @override
  String get communityResource => '社区资源';

  @override
  String get unconfirmed => '未确认';

  @override
  String get confidenceHigh => '可信度高';

  @override
  String get confidenceMedium => '可信度中等';

  @override
  String get confidenceLow => '可信度低';

  @override
  String get trustSource => '来源';

  @override
  String get trustCorroboration => '确认情况';

  @override
  String get trustFreshness => '新鲜度';

  @override
  String confirmationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次确认',
      zero: '还没有确认',
    );
    return '$_temp0';
  }

  @override
  String disputesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个异议',
      zero: '没有异议',
    );
    return '$_temp0';
  }

  @override
  String get oneReport => '目前只有 1 条报告';

  @override
  String officialUpdate(String time) {
    return '官方更新于$time';
  }

  @override
  String lastObservation(String time) {
    return '最近一次观察于$time';
  }

  @override
  String staleWarning(String time) {
    return '最后一次观察于$time，信息可能已过时。';
  }

  @override
  String get voteUseful => '有用';

  @override
  String get voteConfirm => '确认';

  @override
  String get voteConfirmSub => '我亲眼看到了';

  @override
  String get voteDispute => '有异议';

  @override
  String get voteDisputeSub => '我看到的不一样';

  @override
  String get voted => '谢谢。你的报告已签名并共享。';

  @override
  String get voteWithdrawnToast => '已撤回报告';

  @override
  String get approxLocation => '大致位置';

  @override
  String get inventoryTitle => '库存';

  @override
  String officialStock(int count, String time) {
    return '官方数量：$count（$time）';
  }

  @override
  String reservedFor(int count, String id) {
    return '已为任务 $id 预留 $count';
  }

  @override
  String remainingCount(int count) {
    return '剩余 $count';
  }

  @override
  String get communityReports => '社区报告';

  @override
  String observationAt(String text, String time) {
    return '$text（$time）';
  }

  @override
  String get addHereTitle => '在这里添加';

  @override
  String get addHereHint => '在地图上长按，即可添加饮用水、食物、住处或你看到的问题。';

  @override
  String get addNoteHint => '添加简短说明（可选）';

  @override
  String get addResource => '添加';

  @override
  String get resourceAdded => '已添加。其他人看到的是大致位置。';

  @override
  String get resourceRemoved => '已删除';

  @override
  String get addedByYou => '由你添加';

  @override
  String get statusOffline => '离线';

  @override
  String get statusOnline => '在线';

  @override
  String get statusReady => '就绪';

  @override
  String lastSyncAgo(String time) {
    return '上次同步：$time';
  }

  @override
  String alertsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条警报',
    );
    return '$_temp0';
  }

  @override
  String get alertsTitle => '警报';

  @override
  String get layerFacilities => '医院、药房、警察和消防';

  @override
  String get layerLive => '饮用水、食物、住处和报告';

  @override
  String get networkTitle => '网络状态';

  @override
  String get netInternet => '互联网';

  @override
  String get netPeers => '附近的手机';

  @override
  String get netNode => '韧性节点';

  @override
  String get netLora => 'LoRa 电台';

  @override
  String get netLastLocal => '上次与附近同步';

  @override
  String get netLastGlobal => '上次与云端同步';

  @override
  String get netConnected => '已连接';

  @override
  String get netNotConnected => '未连接';

  @override
  String peersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部手机',
      zero: '没有',
    );
    return '$_temp0';
  }

  @override
  String queuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项等待发送',
      zero: '没有等待发送的内容',
    );
    return '$_temp0';
  }

  @override
  String get demoInternet => '演示：假装互联网已恢复';

  @override
  String get demoInternetSub => '看看手机联网后会有什么变化';

  @override
  String get viewRadios => '网络中的电台';

  @override
  String get downloadsTitle => '离线下载';

  @override
  String packageTitle(String region) {
    return '$region应急准备包';
  }

  @override
  String get packageContents => '离线地图、紧急设施、路线数据、可信机构、撤销列表、紧急指南和最新资源状态。';

  @override
  String packageSize(int size, int version) {
    return '$size MB，版本 $version';
  }

  @override
  String packageUpToDate(String time) {
    return '已是最新。下载于$time';
  }

  @override
  String packageUpdate(int version) {
    return '有可用更新：版本 $version';
  }

  @override
  String get downloadNow => '立即下载';

  @override
  String downloadingPercent(int percent) {
    return '正在下载 $percent%';
  }

  @override
  String get downloadNeedsNet => '需要互联网或附近的韧性节点。';

  @override
  String preparednessNotice(String region, int size) {
    return '$region有新的离线包：$size MB';
  }

  @override
  String get download => '下载';

  @override
  String get orgsTitle => '可信机构';

  @override
  String certifiedBy(String name) {
    return '由$name认证';
  }

  @override
  String get rootOfTrust => '信任根';

  @override
  String revocationsChecked(String time) {
    return '证书和撤销列表检查于$time。离线时，这是这部手机上最新的列表。';
  }

  @override
  String get tabPeople => '个人';

  @override
  String get tabOrganizations => '机构';

  @override
  String get scanQr => '扫描二维码';

  @override
  String get myQr => '我的二维码';

  @override
  String get moreWaysToAdd => '其他添加方式';

  @override
  String get addByUsername => '按用户名添加';

  @override
  String get addByPhone => '按电话号码添加';

  @override
  String get needsInternetToFind => '需要互联网。请对方出示二维码。';

  @override
  String get metInPerson => '当面认识';

  @override
  String get addedByUsername => '按用户名添加';

  @override
  String get addedByPhone => '按电话号码添加';

  @override
  String get myQrTitle => '我的韧性 ID';

  @override
  String get myQrHint => '把它给你遇到的人看。它分享的是你的公钥，绝不会分享你的电话号码。';

  @override
  String get resilienceId => '韧性 ID';

  @override
  String get scanTitle => '扫描二维码';

  @override
  String get scanHint => '把摄像头对准二维码。';

  @override
  String get scanUnavailable => '这里无法使用摄像头，请手动输入。';

  @override
  String get typeIdLabel => '对方的韧性 ID';

  @override
  String get typeIdHint => '16 位字母和数字';

  @override
  String get theirName => '对方的名字';

  @override
  String get addContact => '添加联系人';

  @override
  String contactAdded(String name) {
    return '已添加$name';
  }

  @override
  String contactRemoved(String name) {
    return '已删除$name';
  }

  @override
  String get invalidId => '这看起来不像韧性 ID。';

  @override
  String get notFound => '没有找到这个人。';

  @override
  String get usernameLabel => '用户名';

  @override
  String get phoneLabel => '电话号码';

  @override
  String get find => '查找';

  @override
  String get messageAction => '发消息';

  @override
  String get removeContact => '删除';

  @override
  String get noContacts => '还没有联系人。扫描别人的二维码即可添加。';

  @override
  String get tabDirect => '私聊';

  @override
  String get tabCommunity => '社区';

  @override
  String get tabMission => '任务';

  @override
  String get channelPublic => '公开，所有人可读';

  @override
  String get channelCommunity => '社区成员';

  @override
  String get channelRestricted => '仅限工作人员，已加密';

  @override
  String get channelMission => '仅限任务成员';

  @override
  String get channelDirect => '私密';

  @override
  String get readOnlyChannel => '只有已认证机构可以在这里发布。';

  @override
  String sendsOver(String route) {
    return '发送方式：$route';
  }

  @override
  String get routeInternet => '互联网';

  @override
  String get routeLocal => '韧性节点';

  @override
  String get routeMesh => 'LoRa 网络';

  @override
  String get routeQueued => '在手机上等待，直到有可用线路';

  @override
  String get deliveryQueued => '排队中';

  @override
  String get deliveryPropagating => '传送中';

  @override
  String get deliveryDelivered => '已送达';

  @override
  String get deliveryRead => '已读';

  @override
  String get noChannels => '这里还没有对话';

  @override
  String get deliveries => '配送';

  @override
  String get deliveriesSub => '你可以运送的任务';

  @override
  String get tabAvailable => '可接';

  @override
  String get tabAssigned => '已分配';

  @override
  String get tabInTransit => '运送中';

  @override
  String get tabHandoff => '交接';

  @override
  String get tabCompleted => '已完成';

  @override
  String missionTitle(String id) {
    return '任务 $id';
  }

  @override
  String get priorityHigh => '高优先级';

  @override
  String get priorityNormal => '普通优先级';

  @override
  String get priorityLow => '低优先级';

  @override
  String get pickupLabel => '取货地点';

  @override
  String get destinationLabel => '目的地';

  @override
  String get carrierLabel => '运送人';

  @override
  String packageLabel(String id) {
    return '包裹 $id';
  }

  @override
  String get exactHidden => '详细地址只对运送人显示';

  @override
  String get acceptMission => '接受任务';

  @override
  String get missionAccepted => '已接受任务，现在可以看到详细地址。';

  @override
  String get missionReleased => '已退回任务';

  @override
  String get confirmPickup => '确认取货';

  @override
  String get pickedUp => '取货已确认并签名';

  @override
  String get confirmDelivery => '确认送达';

  @override
  String get deliveredToast => '送达已确认并签名';

  @override
  String get handOff => '交接';

  @override
  String get handoffWaiting => '等待下一位司机扫描包裹码';

  @override
  String handoffConfirmed(String name, String id) {
    return '交接已确认：$name拿到了包裹 $id';
  }

  @override
  String get packageCode => '包裹码';

  @override
  String get packageQrHint => '让对方扫描这个码。里面只有包裹编号和签名，没有私密信息。';

  @override
  String get scanPackage => '扫描包裹码';

  @override
  String get enterPackageId => '包裹编号';

  @override
  String wrongPackage(String id) {
    return '这不是包裹 $id。';
  }

  @override
  String get mStageAvailable => '可接';

  @override
  String get mStageAssigned => '已分配给你';

  @override
  String get mStageInTransit => '运送中';

  @override
  String get mStageHandoff => '等待交接';

  @override
  String get mStageDelivered => '已送达';

  @override
  String handedOffTo(String name) {
    return '已交给$name';
  }

  @override
  String get noMissions => '现在没有内容';

  @override
  String get deliveriesHint => '提供交通帮助后，就能看到附近的任务。';

  @override
  String get sectionActivity => '你的动态';

  @override
  String get sectionNetwork => '网络和数据';

  @override
  String get sectionSettings => '设置';

  @override
  String get sectionManage => '管理';

  @override
  String get myRequests => '我的求助';

  @override
  String openCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个进行中',
      zero: '没有进行中的',
    );
    return '$_temp0';
  }

  @override
  String get mySupplies => '我的物资';

  @override
  String get notOffering => '目前没有提供物资';

  @override
  String orgCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个机构',
    );
    return '$_temp0';
  }

  @override
  String get historyTitle => '签名记录';

  @override
  String get historyHint => '每一步都在执行它的手机上签名。';

  @override
  String signedBy(String id) {
    return '签名者 $id';
  }

  @override
  String get evHelpRequested => '发出求助';

  @override
  String get evHelpCancelled => '取消求助';

  @override
  String get evHelpAccepted => '救助者已接受';

  @override
  String get evHelpReleased => '救助者已退出';

  @override
  String get evHelpOffered => '发布了物资';

  @override
  String get evOfferWithdrawn => '撤回了物资';

  @override
  String get evResourceCreated => '添加了资源';

  @override
  String get evResourceRemoved => '删除了资源';

  @override
  String get evResourceConfirmed => '已确认';

  @override
  String get evResourceDisputed => '提出异议';

  @override
  String get evResourceUseful => '标记为有用';

  @override
  String get evVoteWithdrawn => '撤回了报告';

  @override
  String get evContactAdded => '添加了联系人';

  @override
  String get evContactRemoved => '删除了联系人';

  @override
  String get evMessageSent => '发送了消息';

  @override
  String get evMissionAccepted => '接受了任务';

  @override
  String get evMissionReleased => '退回了任务';

  @override
  String get evPackagePickedUp => '取走了包裹';

  @override
  String get evPackageTransferred => '交接了包裹';

  @override
  String get evDeliveryCompleted => '完成了配送';

  @override
  String get stageSavedTheirs => '已保存在对方手机上';

  @override
  String get stageSavedTheirsSub => '保存在那里，直到附近有电台';

  @override
  String get mapSource => '街道地图来自 Amazon Location';

  @override
  String get mapSourceNote => '需要联网。街道地图无法加载时，标记、电台和求助仍会显示。';

  @override
  String get mapNotSetUp => '街道地图尚未设置';

  @override
  String get mapOffline => '街道地图需要联网';

  @override
  String get mapLoading => '正在加载街道地图';

  @override
  String get missionNotFound => '这个配送已不存在。';

  @override
  String get resourceNotFound => '这个地点已不在地图上。';

  @override
  String get lookAdvanced => '高级';

  @override
  String get lookRequestAdvancedSub => '电台、服务器检查和签名记录';

  @override
  String get lookStageSent => '已发送';

  @override
  String get lookStageSentSub => '正在发给附近能帮忙的人';

  @override
  String get lookStageReceived => '已收到';

  @override
  String get lookStageReceivedSub => '能帮忙的人现在可以看到';

  @override
  String get lookStepDone => '已完成';

  @override
  String get lookStepNow => '当前';

  @override
  String get lookStepNext => '未开始';

  @override
  String get lookChatNotFound => '这个对话已不存在。';

  @override
  String get deliverySharingLocation => '正在共享你的位置，直到送达';

  @override
  String get deliveryLocationOnlyWhileCarrying => '只有在你运送这件物资时，才会共享你的位置。';
}
