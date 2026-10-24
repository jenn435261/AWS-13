// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Mesh';

  @override
  String get navMap => 'Bản đồ';

  @override
  String get navMessages => 'Tin nhắn';

  @override
  String get navMore => 'Thêm';

  @override
  String get helpButton => 'Giúp';

  @override
  String get helpButtonSemantics => 'Yêu cầu giúp đỡ';

  @override
  String get helpButtonHint => 'Chạm để xem lựa chọn. Giữ 2 giây để gửi SOS.';

  @override
  String get helpMenuTitle => 'Bạn muốn làm gì?';

  @override
  String get needHelp => 'Tôi cần giúp đỡ';

  @override
  String get needHelpSub => 'Cho người ở gần biết bạn cần gì';

  @override
  String get canHelp => 'Tôi có thể giúp';

  @override
  String get canHelpSub => 'Cho người ở gần biết bạn có thể giúp gì';

  @override
  String get sosTip => 'Gặp nguy hiểm? Giữ nút Giúp màu đỏ để gửi SOS ngay.';

  @override
  String get holdForSos => 'Giữ để gửi SOS';

  @override
  String get holdForSosSub => 'Gửi vị trí của bạn ngay lập tức';

  @override
  String get keepHolding => 'Tiếp tục giữ để gửi SOS';

  @override
  String get sosSent => 'Đã gửi SOS kèm vị trí của bạn';

  @override
  String get undo => 'Hoàn tác';

  @override
  String get redo => 'Làm lại';

  @override
  String get dismiss => 'Bỏ qua';

  @override
  String get next => 'Tiếp';

  @override
  String get close => 'Đóng';

  @override
  String get edit => 'Sửa';

  @override
  String get view => 'Xem';

  @override
  String get send => 'Gửi';

  @override
  String radiosNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bộ đàm gần đây',
      zero: 'Không có bộ đàm gần đây',
    );
    return '$_temp0';
  }

  @override
  String get online => 'Có mạng';

  @override
  String get offline => 'Mất mạng';

  @override
  String get layers => 'Lớp';

  @override
  String get layerRequests => 'Yêu cầu giúp đỡ';

  @override
  String get layerRadios => 'Bộ đàm và vùng phủ sóng';

  @override
  String get myLocation => 'Hiện vị trí của tôi';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get nothingNearby => 'Chưa có gì ở gần';

  @override
  String distanceMeters(int meters) {
    return 'cách $meters m';
  }

  @override
  String distanceKm(String km) {
    return 'cách $km km';
  }

  @override
  String get howItTravels => 'Yêu cầu của bạn được gửi đi thế nào';

  @override
  String get travelPhone => 'Điện thoại này';

  @override
  String get travelPhoneSub => 'Lưu mọi thứ trước, kể cả khi không có sóng';

  @override
  String get travelMesh => 'Mạng bộ đàm';

  @override
  String get travelMeshSub => 'Chuyển từ bộ đàm này sang bộ đàm khác';

  @override
  String get travelCloud => 'AWS';

  @override
  String get travelCloudOnline => 'Kiểm tra và lưu một bản sao';

  @override
  String get travelCloudOffline =>
      'Ngoài tầm. Yêu cầu của bạn chờ trên mạng bộ đàm.';

  @override
  String get travelHelpers => 'Người giúp đỡ';

  @override
  String get travelHelpersSub => 'Thấy yêu cầu của bạn và trả lời';

  @override
  String get showOnMap => 'Xem trên bản đồ';

  @override
  String get openDetails => 'Xem chi tiết';

  @override
  String get kindMedical => 'Cấp cứu y tế';

  @override
  String get kindMedicalSub => 'Bị thương, bị bệnh hoặc bị kẹt';

  @override
  String get kindWater => 'Nước';

  @override
  String get kindWaterSub => 'Nước uống';

  @override
  String get kindShelter => 'Chỗ trú';

  @override
  String get kindShelterSub => 'Một nơi an toàn để ở';

  @override
  String get kindPower => 'Điện';

  @override
  String get kindPowerSub => 'Sạc điện thoại hoặc thiết bị y tế';

  @override
  String get kindOther => 'Việc khác';

  @override
  String get kindOtherSub => 'Mô tả ở bước tiếp theo';

  @override
  String get kindSos => 'SOS';

  @override
  String get urgencyNow => 'Ngay bây giờ';

  @override
  String get urgencyNowSub => 'Nguy hiểm đến tính mạng hoặc an toàn';

  @override
  String get urgencySoon => 'Trong vài giờ';

  @override
  String get urgencySoonSub => 'Đang tệ hơn';

  @override
  String get urgencyLater => 'Có thể chờ';

  @override
  String get urgencyLaterSub => 'Hiện đang ổn định';

  @override
  String get stageSaved => 'Đã lưu trên điện thoại';

  @override
  String get stageSavedSub => 'Sẽ gửi ngay khi có bộ đàm trong tầm';

  @override
  String get stageMesh => 'Đã gửi qua mạng bộ đàm';

  @override
  String stageMeshSub(int hops) {
    String _temp0 = intl.Intl.pluralLogic(
      hops,
      locale: localeName,
      other: 'Đi qua $hops bộ đàm',
      zero: 'Đến thẳng một bộ đàm',
    );
    return '$_temp0';
  }

  @override
  String get stageVerified => 'Máy chủ đã kiểm tra';

  @override
  String get stageVerifiedSub => 'AWS đã kiểm tra yêu cầu và lưu một bản sao';

  @override
  String get stageAssigned => 'Đã có người giúp';

  @override
  String stageAssignedSub(String name) {
    return '$name đã nhận yêu cầu';
  }

  @override
  String get stageOnTheWay => 'Người giúp đang đến';

  @override
  String stageOnTheWaySub(String name) {
    return '$name đang đến đó';
  }

  @override
  String get stageResolved => 'Đã xong';

  @override
  String get stageResolvedSub => 'Đã đánh dấu hoàn tất';

  @override
  String get stageWaiting => 'Đang chờ';

  @override
  String stepOf(int step, int total) {
    return 'Bước $step / $total';
  }

  @override
  String get helpStep1Title => 'Bạn cần gì?';

  @override
  String get helpStep2Title => 'Còn gì nữa không?';

  @override
  String get urgencyQuestion => 'Khẩn cấp đến mức nào?';

  @override
  String get peopleQuestion => 'Bao nhiêu người cần giúp?';

  @override
  String peopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count người',
    );
    return '$_temp0';
  }

  @override
  String get fewerPeople => 'Bớt người';

  @override
  String get morePeople => 'Thêm người';

  @override
  String get locationTitle => 'Vị trí';

  @override
  String locationAuto(int meters) {
    return 'Tự động chia sẻ, chính xác trong $meters m';
  }

  @override
  String get locationMissing =>
      'Không có vị trí của bạn. Hãy mô tả nơi bạn đang ở.';

  @override
  String get locationNoteLabel => 'Mô tả nơi bạn đang ở';

  @override
  String get locationNoteHint => 'Ví dụ: tầng 2, gần cầu thang';

  @override
  String get noteLabel => 'Còn gì nữa không? (không bắt buộc)';

  @override
  String get sendRequest => 'Gửi yêu cầu';

  @override
  String get requestSent => 'Đã gửi yêu cầu';

  @override
  String get requestDiscarded => 'Đã bỏ yêu cầu';

  @override
  String get requestCancelled => 'Đã hủy yêu cầu';

  @override
  String get requestRestored => 'Đã khôi phục yêu cầu';

  @override
  String get cancelRequest => 'Hủy yêu cầu';

  @override
  String get problemMissingKind => 'Hãy chọn thứ bạn cần.';

  @override
  String problemPeople(int max) {
    return 'Nhập từ 1 đến $max người.';
  }

  @override
  String problemNoteTooLong(int max) {
    return 'Ghi chú phải ít hơn $max ký tự.';
  }

  @override
  String get problemLocation =>
      'Hãy mô tả nơi bạn đang ở, vì không có vị trí của bạn.';

  @override
  String get offerStep1Title => 'Những gì tôi có thể giúp';

  @override
  String get offerStep2Title => 'Vài chi tiết';

  @override
  String get offerNoteLabel => 'Ghi chú cho người ở gần (không bắt buộc)';

  @override
  String get offerNoteHint => 'Ví dụ: tôi có xe chở được 4 người';

  @override
  String get startOffering => 'Bắt đầu giúp';

  @override
  String get offeringStarted => 'Bạn đang sẵn sàng giúp đỡ';

  @override
  String offeringList(String list) {
    return 'Bạn có thể giúp: $list';
  }

  @override
  String get stopOffering => 'Dừng';

  @override
  String get offerStopped => 'Bạn đã ngừng giúp đỡ';

  @override
  String get offerPrompt => 'Bạn có thể giúp? Hãy cho người ở gần biết.';

  @override
  String get tabNearMe => 'Gần tôi';

  @override
  String get tabMine => 'Của tôi';

  @override
  String get iCanHelp => 'Tôi giúp';

  @override
  String get youAreHelping => 'Bạn đang giúp';

  @override
  String get stopHelping => 'Ngừng giúp';

  @override
  String get acceptedToast => 'Bạn đang giúp. Họ biết bạn đang đến.';

  @override
  String get releasedToast => 'Bạn đã ngừng giúp';

  @override
  String get noNearby => 'Không có yêu cầu nào ở gần';

  @override
  String get noMine => 'Bạn chưa yêu cầu giúp đỡ';

  @override
  String fromName(String name) {
    return 'Từ $name';
  }

  @override
  String get justNow => 'vừa xong';

  @override
  String minutesAgo(int n) {
    return '$n phút trước';
  }

  @override
  String hoursAgo(int n) {
    return '$n giờ trước';
  }

  @override
  String daysAgo(int n) {
    return '$n ngày trước';
  }

  @override
  String get progressTitle => 'Tiến trình';

  @override
  String get detailsTitle => 'Chi tiết';

  @override
  String get showToResponder => 'Cho người cứu hộ xem';

  @override
  String get requestNotFound => 'Yêu cầu này không còn nữa.';

  @override
  String get cardNeedHelp => 'Tôi cần giúp đỡ';

  @override
  String get cardSwipeHint => 'Vuốt sang trái hoặc phải để đổi ngôn ngữ';

  @override
  String get cardTheirWords => 'Lời của họ, chưa dịch:';

  @override
  String get urgencyTitle => 'Mức khẩn cấp';

  @override
  String get peopleTitle => 'Số người';

  @override
  String get noMessages => 'Chưa có tin nhắn';

  @override
  String get messageHint => 'Tin nhắn';

  @override
  String get languageSystem => 'Theo điện thoại';

  @override
  String get display => 'Hiển thị và trợ năng';

  @override
  String displaySub(int percent) {
    return 'Cỡ chữ $percent%';
  }

  @override
  String get theme => 'Giao diện';

  @override
  String get themeAuto => 'Tự động';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get textSize => 'Cỡ chữ';

  @override
  String get highContrast => 'Độ tương phản cao';

  @override
  String get highContrastSub => 'Màu và viền đậm hơn';

  @override
  String get textPreview => 'Chữ sẽ trông như thế này.';

  @override
  String get privacy => 'Quyền riêng tư và bảo mật';

  @override
  String get phoneLockOn => 'Khóa ứng dụng đang bật';

  @override
  String get phoneLockOff => 'Khóa ứng dụng đang tắt';

  @override
  String get phoneLock => 'Khóa bằng Face ID hoặc vân tay';

  @override
  String get phoneLockSub => 'Dùng mật mã điện thoại nếu không được';

  @override
  String get phoneLockWeb => 'Có trong ứng dụng iOS và Android';

  @override
  String get phoneLockUnavailable =>
      'Hãy cài mật mã hoặc Face ID trên điện thoại trước';

  @override
  String get lockNow => 'Khóa ngay';

  @override
  String get lockNowSub => 'Vẫn gửi SOS được khi đang khóa';

  @override
  String get clearTemp => 'Xóa dữ liệu tạm';

  @override
  String get clearTempSub =>
      'Tin nhắn cũ và yêu cầu đã xong. AWS vẫn giữ bản sao.';

  @override
  String cleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã xóa $count mục',
      zero: 'Không có gì để xóa',
    );
    return '$_temp0';
  }

  @override
  String get eraseAll => 'Xóa mọi thứ trên điện thoại này';

  @override
  String get eraseAllSub => 'Giữ 3 giây. Không thể hoàn tác.';

  @override
  String get erased => 'Đã xóa mọi thứ trên điện thoại này';

  @override
  String get network => 'Mạng bộ đàm';

  @override
  String get manage => 'Quản lý mạng';

  @override
  String get manageSub => 'Bật hoặc tắt bộ đàm cho mọi người';

  @override
  String get admin => 'Người dùng và vai trò';

  @override
  String get adminSub => 'Đổi người được quản lý mạng';

  @override
  String get account => 'Tài khoản';

  @override
  String signedInAs(String name) {
    return 'Đã đăng nhập: $name';
  }

  @override
  String get guestMode => 'Đang dùng Mesh với tư cách khách';

  @override
  String get signIn => 'Đăng nhập';

  @override
  String get signInSub =>
      'Không bắt buộc. Người giúp và người quản lý đăng nhập.';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String get nameLabel => 'Tên';

  @override
  String get roleLabel => 'Vai trò';

  @override
  String get roleClient => 'Thành viên';

  @override
  String get roleManager => 'Người quản lý';

  @override
  String get roleAdmin => 'Quản trị viên';

  @override
  String get demoSignIn =>
      'Đăng nhập thử. Trong ứng dụng thật, máy chủ cấp vai trò cho bạn.';

  @override
  String get nodeOnline => 'Có mạng';

  @override
  String get nodeOffline => 'Mất mạng';

  @override
  String get hopsDirect => 'Trực tiếp';

  @override
  String hopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chặng',
    );
    return '$_temp0';
  }

  @override
  String get externalPower => 'Nguồn điện ngoài';

  @override
  String get noNodes => 'Chưa nghe thấy bộ đàm nào';

  @override
  String get nodeId => 'ID';

  @override
  String get lastHeard => 'Lần cuối nghe thấy';

  @override
  String get battery => 'Pin';

  @override
  String get signalStrength => 'Cường độ tín hiệu';

  @override
  String get signalNoise => 'Tín hiệu so với nhiễu';

  @override
  String get hopsTitle => 'Số chặng';

  @override
  String get manageHint => 'Bộ đàm bạn tắt sẽ bị ẩn với thành viên.';

  @override
  String get loadFailed => 'Không tải được trang này.';

  @override
  String get lockedTitle => 'Mesh đang khóa';

  @override
  String get lockedSub => 'Mở khóa để xem yêu cầu và tin nhắn.';

  @override
  String get unlock => 'Mở khóa';

  @override
  String get unlockReason => 'Mở khóa Mesh';

  @override
  String get unlockWebNote =>
      'Bản xem trên web không có Face ID, nên Mở khóa sẽ mở thẳng ứng dụng.';

  @override
  String get unlockFailed =>
      'Không mở khóa được. Hãy thử lại hoặc dùng mật mã.';

  @override
  String alertNearby(String kind) {
    return 'Yêu cầu mới ở gần: $kind';
  }

  @override
  String alertHelper(String name) {
    return '$name đã nhận yêu cầu của bạn';
  }

  @override
  String get navContacts => 'Danh bạ';

  @override
  String get kindFood => 'Thức ăn';

  @override
  String get kindFoodSub => 'Bữa ăn hoặc sữa cho em bé';

  @override
  String get kindMedicine => 'Thuốc';

  @override
  String get kindMedicineSub => 'Thuốc theo toa, insulin, ống hít';

  @override
  String get kindTransportation => 'Đi lại';

  @override
  String get kindTransportationSub =>
      'Cần xe đưa đi, hoặc giúp di chuyển người';

  @override
  String get kindCommunication => 'Liên lạc';

  @override
  String get kindCommunicationSub => 'Liên lạc với gia đình hoặc gọi trợ giúp';

  @override
  String get noteExampleHint =>
      'Ví dụ: cần chỗ lạnh để giữ insulin cho một người';

  @override
  String get structuredFirst =>
      'Lựa chọn của bạn được gửi trước, nên vẫn đến được khi sóng yếu. Ghi chú sẽ gửi sau khi có chỗ.';

  @override
  String suggestion(String kind) {
    return 'Có vẻ là: $kind';
  }

  @override
  String get useSuggestion => 'Dùng mục này';

  @override
  String get amountQuestion => 'Bạn có bao nhiêu?';

  @override
  String get amountPlenty => 'Nhiều';

  @override
  String get amountSome => 'Vừa';

  @override
  String get amountLow => 'Ít';

  @override
  String get availabilityQuestion => 'Khi nào có?';

  @override
  String get availabilityNow => 'Ngay bây giờ';

  @override
  String get availabilityToday => 'Hôm nay';

  @override
  String get availabilityCustom => 'Lúc khác';

  @override
  String get availabilityNoteLabel => 'Khi nào?';

  @override
  String get availabilityNoteHint => 'Ví dụ: sau 6 giờ tối';

  @override
  String get transportQuestion => 'Bạn chở bằng gì?';

  @override
  String get transportWalking => 'Đi bộ';

  @override
  String get transportBicycle => 'Xe đạp';

  @override
  String get transportCar => 'Xe hơi';

  @override
  String get transportTruck => 'Xe tải';

  @override
  String get transportVan => 'Xe van';

  @override
  String get capacityQuestion => 'Bạn chở được bao nhiêu?';

  @override
  String get capacitySmall => 'Ít';

  @override
  String get capacityMedium => 'Vừa';

  @override
  String get capacityLarge => 'Nhiều';

  @override
  String get supplyWater => 'Nước';

  @override
  String get supplyFood => 'Thức ăn';

  @override
  String get supplyBlankets => 'Chăn';

  @override
  String get supplyBatteries => 'Pin';

  @override
  String get supplyCharging => 'Sạc điện';

  @override
  String get supplyMedicine => 'Thuốc';

  @override
  String get supplyTransportation => 'Đi lại';

  @override
  String get supplyShelter => 'Chỗ trú';

  @override
  String get supplyTools => 'Dụng cụ';

  @override
  String get supplyOther => 'Thứ khác';

  @override
  String get problemSupplies => 'Hãy chọn ít nhất một thứ.';

  @override
  String get problemTransport => 'Hãy chọn cách bạn chở.';

  @override
  String get resHospital => 'Bệnh viện';

  @override
  String get resPharmacy => 'Nhà thuốc';

  @override
  String get resPolice => 'Cảnh sát';

  @override
  String get resFire => 'Trạm cứu hỏa';

  @override
  String get resWater => 'Nước';

  @override
  String get resFood => 'Thức ăn';

  @override
  String get resShelter => 'Chỗ trú';

  @override
  String get resCharging => 'Sạc điện';

  @override
  String get resTransportation => 'Đi lại';

  @override
  String get resRoadProblem => 'Sự cố trên đường';

  @override
  String get verifiedOrg => 'Tổ chức đã xác minh';

  @override
  String get communityResource => 'Nguồn từ cộng đồng';

  @override
  String get unconfirmed => 'Chưa xác nhận';

  @override
  String get confidenceHigh => 'Độ tin cậy cao';

  @override
  String get confidenceMedium => 'Độ tin cậy vừa';

  @override
  String get confidenceLow => 'Độ tin cậy thấp';

  @override
  String get trustSource => 'Nguồn';

  @override
  String get trustCorroboration => 'Xác nhận';

  @override
  String get trustFreshness => 'Độ mới';

  @override
  String confirmationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lượt xác nhận',
      zero: 'Chưa có xác nhận',
    );
    return '$_temp0';
  }

  @override
  String disputesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phản đối',
      zero: 'không có phản đối',
    );
    return '$_temp0';
  }

  @override
  String get oneReport => 'Mới có 1 báo cáo';

  @override
  String officialUpdate(String time) {
    return 'Cập nhật chính thức $time';
  }

  @override
  String lastObservation(String time) {
    return 'Lần thấy gần nhất $time';
  }

  @override
  String staleWarning(String time) {
    return 'Thấy lần cuối $time. Có thể đã cũ.';
  }

  @override
  String get voteUseful => 'Hữu ích';

  @override
  String get voteConfirm => 'Xác nhận';

  @override
  String get voteConfirmSub => 'Tôi tự thấy';

  @override
  String get voteDispute => 'Phản đối';

  @override
  String get voteDisputeSub => 'Tôi thấy khác';

  @override
  String get voted => 'Cảm ơn. Báo cáo của bạn đã được ký và chia sẻ.';

  @override
  String get voteWithdrawnToast => 'Đã rút báo cáo';

  @override
  String get approxLocation => 'Vị trí gần đúng';

  @override
  String get inventoryTitle => 'Số lượng';

  @override
  String officialStock(int count, String time) {
    return 'Số chính thức: $count lúc $time';
  }

  @override
  String reservedFor(int count, String id) {
    return '$count đã giữ cho Nhiệm vụ $id';
  }

  @override
  String remainingCount(int count) {
    return 'Còn $count';
  }

  @override
  String get communityReports => 'Báo cáo từ cộng đồng';

  @override
  String observationAt(String text, String time) {
    return '$text lúc $time';
  }

  @override
  String get addHereTitle => 'Thêm vào đây';

  @override
  String get addHereHint =>
      'Giữ ngón tay trên bản đồ để thêm nước, thức ăn, chỗ trú hoặc sự cố bạn thấy.';

  @override
  String get addNoteHint => 'Thêm ghi chú ngắn (không bắt buộc)';

  @override
  String get addResource => 'Thêm';

  @override
  String get resourceAdded => 'Đã thêm. Người khác thấy vị trí gần đúng.';

  @override
  String get resourceRemoved => 'Đã xóa';

  @override
  String get addedByYou => 'Do bạn thêm';

  @override
  String get statusOffline => 'Mất mạng';

  @override
  String get statusOnline => 'Có mạng';

  @override
  String get statusReady => 'Sẵn sàng';

  @override
  String lastSyncAgo(String time) {
    return 'Đồng bộ lần cuối $time';
  }

  @override
  String alertsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cảnh báo',
    );
    return '$_temp0';
  }

  @override
  String get alertsTitle => 'Cảnh báo';

  @override
  String get layerFacilities => 'Bệnh viện, nhà thuốc, cảnh sát và cứu hỏa';

  @override
  String get layerLive => 'Nước, thức ăn, chỗ trú và báo cáo';

  @override
  String get networkTitle => 'Tình trạng mạng';

  @override
  String get netInternet => 'Internet';

  @override
  String get netPeers => 'Điện thoại ở gần';

  @override
  String get netNode => 'Trạm Resilience';

  @override
  String get netLora => 'Bộ đàm LoRa';

  @override
  String get netLastLocal => 'Đồng bộ gần nhất ở quanh đây';

  @override
  String get netLastGlobal => 'Đồng bộ gần nhất với đám mây';

  @override
  String get netConnected => 'Đã kết nối';

  @override
  String get netNotConnected => 'Chưa kết nối';

  @override
  String peersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count điện thoại',
      zero: 'Không có',
    );
    return '$_temp0';
  }

  @override
  String queuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mục đang chờ gửi',
      zero: 'Không có gì đang chờ gửi',
    );
    return '$_temp0';
  }

  @override
  String get demoInternet => 'Thử: giả vờ đã có lại internet';

  @override
  String get demoInternetSub =>
      'Cho thấy điều gì thay đổi khi điện thoại có mạng';

  @override
  String get viewRadios => 'Bộ đàm trên mạng';

  @override
  String get downloadsTitle => 'Tải về để dùng khi mất mạng';

  @override
  String packageTitle(String region) {
    return 'Gói chuẩn bị cho $region';
  }

  @override
  String get packageContents =>
      'Bản đồ ngoại tuyến, cơ sở khẩn cấp, dữ liệu chỉ đường, tổ chức tin cậy, danh sách thu hồi, hướng dẫn khẩn cấp và tình trạng nguồn hỗ trợ gần đây.';

  @override
  String packageSize(int size, int version) {
    return '$size MB, phiên bản $version';
  }

  @override
  String packageUpToDate(String time) {
    return 'Đã mới nhất. Tải về $time';
  }

  @override
  String packageUpdate(int version) {
    return 'Có bản cập nhật: phiên bản $version';
  }

  @override
  String get downloadNow => 'Tải ngay';

  @override
  String downloadingPercent(int percent) {
    return 'Đang tải $percent%';
  }

  @override
  String get downloadNeedsNet => 'Cần internet hoặc một trạm Resilience ở gần.';

  @override
  String preparednessNotice(String region, int size) {
    return 'Gói ngoại tuyến mới cho $region: $size MB';
  }

  @override
  String get download => 'Tải về';

  @override
  String get orgsTitle => 'Tổ chức tin cậy';

  @override
  String certifiedBy(String name) {
    return 'Được chứng nhận bởi $name';
  }

  @override
  String get rootOfTrust => 'Gốc tin cậy';

  @override
  String revocationsChecked(String time) {
    return 'Đã kiểm tra chứng chỉ và danh sách thu hồi $time. Khi mất mạng, đây là danh sách mới nhất điện thoại có.';
  }

  @override
  String get tabPeople => 'Mọi người';

  @override
  String get tabOrganizations => 'Tổ chức';

  @override
  String get scanQr => 'Quét QR';

  @override
  String get myQr => 'QR của tôi';

  @override
  String get moreWaysToAdd => 'Cách thêm khác';

  @override
  String get addByUsername => 'Thêm bằng tên người dùng';

  @override
  String get addByPhone => 'Thêm bằng số điện thoại';

  @override
  String get needsInternetToFind => 'Cần internet. Hãy nhờ họ cho xem mã QR.';

  @override
  String get metInPerson => 'Đã gặp trực tiếp';

  @override
  String get addedByUsername => 'Thêm bằng tên người dùng';

  @override
  String get addedByPhone => 'Thêm bằng số điện thoại';

  @override
  String get myQrTitle => 'ID Resilience của tôi';

  @override
  String get myQrHint =>
      'Cho người bạn gặp xem mã này. Nó chia sẻ khóa công khai, không bao giờ chia sẻ số điện thoại.';

  @override
  String get resilienceId => 'ID Resilience';

  @override
  String get scanTitle => 'Quét mã QR';

  @override
  String get scanHint => 'Hướng camera vào mã QR.';

  @override
  String get scanUnavailable => 'Không dùng được camera ở đây. Hãy nhập tay.';

  @override
  String get typeIdLabel => 'ID Resilience của họ';

  @override
  String get typeIdHint => '16 chữ và số';

  @override
  String get theirName => 'Tên của họ';

  @override
  String get addContact => 'Thêm liên hệ';

  @override
  String contactAdded(String name) {
    return 'Đã thêm $name';
  }

  @override
  String contactRemoved(String name) {
    return 'Đã xóa $name';
  }

  @override
  String get invalidId => 'Đây không giống ID Resilience.';

  @override
  String get notFound => 'Không tìm thấy ai.';

  @override
  String get usernameLabel => 'Tên người dùng';

  @override
  String get phoneLabel => 'Số điện thoại';

  @override
  String get find => 'Tìm';

  @override
  String get messageAction => 'Nhắn tin';

  @override
  String get removeContact => 'Xóa';

  @override
  String get noContacts => 'Chưa có liên hệ. Quét mã QR của ai đó để thêm.';

  @override
  String get tabDirect => 'Riêng';

  @override
  String get tabCommunity => 'Cộng đồng';

  @override
  String get tabMission => 'Nhiệm vụ';

  @override
  String get channelPublic => 'Công khai. Ai cũng đọc được.';

  @override
  String get channelCommunity => 'Thành viên cộng đồng';

  @override
  String get channelRestricted => 'Chỉ nhân viên, đã mã hóa';

  @override
  String get channelMission => 'Chỉ nhóm nhiệm vụ';

  @override
  String get channelDirect => 'Riêng tư';

  @override
  String get readOnlyChannel => 'Chỉ tổ chức đã xác minh đăng ở đây.';

  @override
  String sendsOver(String route) {
    return 'Gửi qua: $route';
  }

  @override
  String get routeInternet => 'Internet';

  @override
  String get routeLocal => 'Trạm Resilience';

  @override
  String get routeMesh => 'Mạng LoRa';

  @override
  String get routeQueued => 'Chờ trên điện thoại đến khi có đường gửi';

  @override
  String get deliveryQueued => 'Đang chờ';

  @override
  String get deliveryPropagating => 'Đang gửi đi';

  @override
  String get deliveryDelivered => 'Đã đến';

  @override
  String get deliveryRead => 'Đã đọc';

  @override
  String get noChannels => 'Chưa có cuộc trò chuyện nào';

  @override
  String get deliveries => 'Giao hàng';

  @override
  String get deliveriesSub => 'Nhiệm vụ bạn có thể chở';

  @override
  String get tabAvailable => 'Đang mở';

  @override
  String get tabAssigned => 'Được giao';

  @override
  String get tabInTransit => 'Đang chở';

  @override
  String get tabHandoff => 'Bàn giao';

  @override
  String get tabCompleted => 'Đã xong';

  @override
  String missionTitle(String id) {
    return 'Nhiệm vụ $id';
  }

  @override
  String get priorityHigh => 'Ưu tiên cao';

  @override
  String get priorityNormal => 'Ưu tiên thường';

  @override
  String get priorityLow => 'Ưu tiên thấp';

  @override
  String get pickupLabel => 'Nơi nhận';

  @override
  String get destinationLabel => 'Nơi đến';

  @override
  String get carrierLabel => 'Người chở';

  @override
  String packageLabel(String id) {
    return 'Kiện hàng $id';
  }

  @override
  String get exactHidden => 'Địa chỉ chính xác chỉ hiện cho người chở';

  @override
  String get acceptMission => 'Nhận nhiệm vụ';

  @override
  String get missionAccepted =>
      'Đã nhận nhiệm vụ. Giờ bạn thấy được địa chỉ chính xác.';

  @override
  String get missionReleased => 'Đã trả lại nhiệm vụ';

  @override
  String get confirmPickup => 'Xác nhận đã nhận hàng';

  @override
  String get pickedUp => 'Đã xác nhận và ký việc nhận hàng';

  @override
  String get confirmDelivery => 'Xác nhận đã giao';

  @override
  String get deliveredToast => 'Đã xác nhận và ký việc giao hàng';

  @override
  String get handOff => 'Bàn giao';

  @override
  String get handoffWaiting => 'Đang chờ người chở tiếp theo quét mã kiện hàng';

  @override
  String handoffConfirmed(String name, String id) {
    return 'Đã bàn giao: $name đang giữ kiện hàng $id';
  }

  @override
  String get packageCode => 'Mã kiện hàng';

  @override
  String get packageQrHint =>
      'Người kia quét mã này. Nó chứa số kiện hàng và chữ ký, không có gì riêng tư.';

  @override
  String get scanPackage => 'Quét mã kiện hàng';

  @override
  String get enterPackageId => 'Số kiện hàng';

  @override
  String wrongPackage(String id) {
    return 'Đây không phải kiện hàng $id.';
  }

  @override
  String get mStageAvailable => 'Đang mở';

  @override
  String get mStageAssigned => 'Đã giao cho bạn';

  @override
  String get mStageInTransit => 'Đang chở';

  @override
  String get mStageHandoff => 'Chờ bàn giao';

  @override
  String get mStageDelivered => 'Đã giao';

  @override
  String handedOffTo(String name) {
    return 'Đã bàn giao cho $name';
  }

  @override
  String get noMissions => 'Hiện chưa có gì';

  @override
  String get deliveriesHint =>
      'Hãy nhận chở hàng để thấy các nhiệm vụ gần bạn.';

  @override
  String get sectionActivity => 'Hoạt động của bạn';

  @override
  String get sectionNetwork => 'Mạng và dữ liệu';

  @override
  String get sectionSettings => 'Cài đặt';

  @override
  String get sectionManage => 'Quản lý';

  @override
  String get myRequests => 'Yêu cầu của tôi';

  @override
  String openCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count đang mở',
      zero: 'Không có yêu cầu mở',
    );
    return '$_temp0';
  }

  @override
  String get mySupplies => 'Những gì tôi giúp';

  @override
  String get notOffering => 'Chưa giúp gì';

  @override
  String orgCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tổ chức',
    );
    return '$_temp0';
  }

  @override
  String get historyTitle => 'Lịch sử đã ký';

  @override
  String get historyHint => 'Mỗi bước được ký trên điện thoại đã thực hiện nó.';

  @override
  String signedBy(String id) {
    return 'Ký bởi $id';
  }

  @override
  String get evHelpRequested => 'Đã yêu cầu giúp đỡ';

  @override
  String get evHelpCancelled => 'Đã hủy yêu cầu';

  @override
  String get evHelpAccepted => 'Người giúp đã nhận';

  @override
  String get evHelpReleased => 'Người giúp đã rút lui';

  @override
  String get evHelpOffered => 'Đã đăng lời giúp';

  @override
  String get evOfferWithdrawn => 'Đã rút lời giúp';

  @override
  String get evResourceCreated => 'Đã thêm nguồn hỗ trợ';

  @override
  String get evResourceRemoved => 'Đã xóa nguồn hỗ trợ';

  @override
  String get evResourceConfirmed => 'Đã xác nhận';

  @override
  String get evResourceDisputed => 'Đã phản đối';

  @override
  String get evResourceUseful => 'Đánh dấu hữu ích';

  @override
  String get evVoteWithdrawn => 'Đã rút báo cáo';

  @override
  String get evContactAdded => 'Đã thêm liên hệ';

  @override
  String get evContactRemoved => 'Đã xóa liên hệ';

  @override
  String get evMessageSent => 'Đã gửi tin nhắn';

  @override
  String get evMissionAccepted => 'Đã nhận nhiệm vụ';

  @override
  String get evMissionReleased => 'Đã trả nhiệm vụ';

  @override
  String get evPackagePickedUp => 'Đã nhận kiện hàng';

  @override
  String get evPackageTransferred => 'Đã bàn giao kiện hàng';

  @override
  String get evDeliveryCompleted => 'Đã giao xong';

  @override
  String get stageSavedTheirs => 'Đã lưu trên điện thoại của họ';

  @override
  String get stageSavedTheirsSub => 'Được giữ ở đó cho đến khi có radio gần';

  @override
  String get mapSource => 'Bản đồ đường phố từ Amazon Location';

  @override
  String get mapSourceNote =>
      'Cần internet. Ghim, radio và yêu cầu vẫn hiện khi bản đồ đường phố không tải được.';

  @override
  String get mapNotSetUp => 'Chưa thiết lập bản đồ đường phố';

  @override
  String get mapOffline => 'Bản đồ đường phố cần internet';

  @override
  String get mapLoading => 'Đang tải bản đồ đường phố';

  @override
  String get missionNotFound => 'Chuyến giao hàng này không còn nữa.';

  @override
  String get resourceNotFound => 'Địa điểm này không còn trên bản đồ.';
}
