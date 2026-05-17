import 'package:flutter/material.dart';

/// Localized strings used by [AppReviewDialog].
class AppReviewLocalizations {
  final String title;
  final String ratingLabel;
  final String positiveTitle;
  final String positiveSubtitle;
  final String negativeTitle;
  final String negativeSubtitle;
  final String rateButtonLabel;
  final String supportButtonLabel;
  final String emailButtonLabel;

  const AppReviewLocalizations({
    required this.title,
    required this.ratingLabel,
    required this.positiveTitle,
    required this.positiveSubtitle,
    required this.negativeTitle,
    required this.negativeSubtitle,
    required this.rateButtonLabel,
    required this.supportButtonLabel,
    required this.emailButtonLabel,
  });

  static AppReviewLocalizations of(BuildContext context) {
    return Localizations.of<AppReviewLocalizations>(
          context,
          AppReviewLocalizations,
        ) ??
        _fallback;
  }

  static const _fallback = AppReviewLocalizations(
    title: 'How much do you enjoy the app?',
    ratingLabel: 'Tap to rate',
    positiveTitle: 'Thank you!',
    positiveSubtitle:
        "We'd be grateful if you could share the love leaving a review in the store!",
    negativeTitle: 'How can we make it better?',
    negativeSubtitle: 'Your feedback helps us improve.',
    rateButtonLabel: 'Rate in store',
    supportButtonLabel: 'Support & Contribute',
    emailButtonLabel: 'Send us an email',
  );
}

// ---------------------------------------------------------------------------
// Delegate
// ---------------------------------------------------------------------------

class _AppReviewLocalizationsDelegate
    extends LocalizationsDelegate<AppReviewLocalizations> {
  const _AppReviewLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      _data.containsKey(locale.languageCode) || _data.containsKey(locale.toLanguageTag());

  @override
  Future<AppReviewLocalizations> load(Locale locale) async {
    final s = _data[locale.languageCode] ??
        _data[locale.toLanguageTag()] ??
        _data['en']!;
    return AppReviewLocalizations(
      title: s.title,
      ratingLabel: s.rl,
      positiveTitle: s.pt,
      positiveSubtitle: s.ps,
      negativeTitle: s.nt,
      negativeSubtitle: s.ns,
      rateButtonLabel: s.rb,
      supportButtonLabel: s.sb,
      emailButtonLabel: s.eb,
    );
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppReviewLocalizations> old) =>
      false;
}

/// The [LocalizationsDelegate] for this package.
///
/// Add it to your app's `localizationsDelegates` list.
const appReviewLocalizationsDelegate = _AppReviewLocalizationsDelegate();

/// All locales supported by this package.
const supportedAppReviewLocales = [
  Locale('en'),
  Locale('ar'),
  Locale('ca'),
  Locale('da'),
  Locale('de'),
  Locale('el'),
  Locale('es'),
  Locale('fr'),
  Locale('hr'),
  Locale('it'),
  Locale('ja'),
  Locale('or'),
  Locale('pl'),
  Locale('pt', 'BR'),
  Locale('pt', 'PT'),
  Locale('ru'),
  Locale('ta'),
  Locale('tr'),
  Locale('uk'),
  Locale('vec'),
  Locale('zh'),
];

// ---------------------------------------------------------------------------
// String data (keyed by ISO 639‑1 language code)
// ---------------------------------------------------------------------------

class _LS {
  final String title;
  final String rl;
  final String pt;
  final String ps;
  final String nt;
  final String ns;
  final String rb;
  final String sb;
  final String eb;

  const _LS({
    required this.title,
    required this.rl,
    required this.pt,
    required this.ps,
    required this.nt,
    required this.ns,
    required this.rb,
    required this.sb,
    required this.eb,
  });
}

const _data = <String, _LS>{
  'en': _LS(
    title: 'How much do you enjoy the app?',
    rl: 'Tap to rate',
    pt: 'Thank you!',
    ps: "We'd be grateful if you could share the love leaving a review in the store!",
    nt: 'How can we make it better?',
    ns: 'Your feedback helps us improve.',
    rb: 'Rate in store',
    sb: 'Support & Contribute',
    eb: 'Send us an email',
  ),
  'ar': _LS(
    title: 'ما مدى استمتاعك بالتطبيق؟',
    rl: 'اضغط للتقييم',
    pt: 'شكراً لك!',
    ps: 'سنكون ممتنين لو شاركتنا الحب بترك تقييم في المتجر!',
    nt: 'كيف يمكننا تحسينه؟',
    ns: 'ملاحظاتك تساعدنا على التحسين.',
    rb: 'تقييم في المتجر',
    sb: 'الدعم والمساهمة',
    eb: 'أرسل لنا بريداً إلكترونياً',
  ),
  'ca': _LS(
    title: 'Quant t\'agrada l\'app?',
    rl: 'Toca per valorar',
    pt: 'Gràcies!',
    ps: 'Estaríem molt agraïts si poguessis compartir l\'amor deixant una ressenya a la botiga!',
    nt: 'Com podem millorar?',
    ns: 'Els teus comentaris ens ajuden a millorar.',
    rb: 'Valorar a la botiga',
    sb: 'Suport i contribuir',
    eb: 'Envia\'ns un correu',
  ),
  'da': _LS(
    title: 'Hvor godt kan du lide appen?',
    rl: 'Tryk for at bedømme',
    pt: 'Tak!',
    ps: 'Vi ville være taknemmelige, hvis du ville dele kærligheden ved at efterlade en anmeldelse i butikken!',
    nt: 'Hvordan kan vi gøre det bedre?',
    ns: 'Din feedback hjælper os med at forbedre.',
    rb: 'Bedøm i butik',
    sb: 'Support & Bidrag',
    eb: 'Send os en e-mail',
  ),
  'de': _LS(
    title: 'Wie sehr gefällt dir die App?',
    rl: 'Tippe zum Bewerten',
    pt: 'Vielen Dank!',
    ps: 'Wir würden uns freuen, wenn du deine Begeisterung mit einer Bewertung im Store teilen würdest!',
    nt: 'Was können wir verbessern?',
    ns: 'Dein Feedback hilft uns, besser zu werden.',
    rb: 'Im Store bewerten',
    sb: 'Support & Mitwirken',
    eb: 'E-Mail senden',
  ),
  'el': _LS(
    title: 'Πόσο απολαμβάνετε την εφαρμογή;',
    rl: 'Πατήστε για βαθμολόγηση',
    pt: 'Ευχαριστούμε!',
    ps: 'Θα ήμασταν ευγνώμονες αν μπορούσατε να μοιραστείτε την αγάπη αφήνοντας μια κριτική στο κατάστημα!',
    nt: 'Πώς μπορούμε να το κάνουμε καλύτερο;',
    ns: 'Τα σχόλιά σας μας βοηθούν να βελτιωθούμε.',
    rb: 'Αξιολόγηση στο κατάστημα',
    sb: 'Υποστήριξη & Συνεισφορά',
    eb: 'Στείλτε μας email',
  ),
  'es': _LS(
    title: '¿Cuánto disfrutas la app?',
    rl: 'Toca para valorar',
    pt: '¡Gracias!',
    ps: '¡Estaríamos muy agradecidos si pudieras compartir el amor dejando una reseña en la tienda!',
    nt: '¿Cómo podemos mejorarla?',
    ns: 'Tus comentarios nos ayudan a mejorar.',
    rb: 'Valorar en la tienda',
    sb: 'Soporte y contribuir',
    eb: 'Envíanos un correo',
  ),
  'fr': _LS(
    title: 'À quel point aimez-vous l\'application ?',
    rl: 'Appuyez pour noter',
    pt: 'Merci !',
    ps: 'Nous serions reconnaissants si vous pouviez partager votre enthousiasme en laissant un avis sur le store !',
    nt: 'Comment pouvons-nous l\'améliorer ?',
    ns: 'Vos commentaires nous aident à progresser.',
    rb: 'Noter sur le store',
    sb: 'Support & Contribuer',
    eb: 'Envoyez-nous un e-mail',
  ),
  'hr': _LS(
    title: 'Koliko uživate u aplikaciji?',
    rl: 'Dodirnite za ocjenu',
    pt: 'Hvala!',
    ps: 'Bili bismo zahvalni ako biste podijelili ljubav ostavljajući recenziju u trgovini!',
    nt: 'Kako možemo poboljšati?',
    ns: 'Vaše povratne informacije pomažu nam da se poboljšamo.',
    rb: 'Ocijeni u trgovini',
    sb: 'Podrška & Doprinesi',
    eb: 'Pošaljite nam e-mail',
  ),
  'it': _LS(
    title: 'Quanto ti piace l\'app?',
    rl: 'Tocca per valutare',
    pt: 'Grazie!',
    ps: 'Ti saremmo grati se potessi condividere l\'amore lasciando una recensione nello store!',
    nt: 'Come possiamo migliorare?',
    ns: 'Il tuo feedback ci aiuta a migliorare.',
    rb: 'Valuta nello store',
    sb: 'Supporto & Contribuisci',
    eb: 'Inviaci un\'email',
  ),
  'ja': _LS(
    title: 'このアプリはどのくらいお楽しみいただいていますか？',
    rl: 'タップして評価',
    pt: 'ありがとうございます！',
    ps: 'ストアにレビューを残して、みんなに広めていただけると嬉しいです！',
    nt: 'どうす改善できますか？',
    ns: 'フィードバックが改善の助けになります。',
    rb: 'ストアで評価する',
    sb: 'サポート & 貢献',
    eb: 'メールを送信',
  ),
  'or': _LS(
    title: 'ଆପଣ ଆପଟି କେତେ ଉପଭୋଗ କରନ୍ତି?',
    rl: 'ମୂଲ୍ୟାଙ୍କନ ପାଇଁ ଟାପ କରନ୍ତୁ',
    pt: 'ଧନ୍ୟବାଦ!',
    ps: 'ଯଦି ଆପଣ ଷ୍ଟୋରରେ ଏକ ସମୀକ୍ଷା ଛାଡ଼ି ଭଲ ପାଇବା ବାଣ୍ଟିପାରିବେ ତେବେ ଆମେ କୃତଜ୍ଞ ହେବୁ!',
    nt: 'ଆମେ ଏହାକୁ କିପରି ଉନ୍ନତ କରିପାରିବା?',
    ns: 'ଆପଣଙ୍କ ମତାମତ ଆମକୁ ଉନ୍ନତି କରିବାରେ ସାହାଯ୍ୟ କରେ।',
    rb: 'ଷ୍ଟୋରରେ ମୂଲ୍ୟାଙ୍କନ କରନ୍ତୁ',
    sb: 'ସମର୍ଥନ ଏବଂ ଯୋଗଦାନ',
    eb: 'ଆମକୁ ଇମେଲ ପଠାନ୍ତୁ',
  ),
  'pl': _LS(
    title: 'Jak bardzo podoba Ci się ta aplikacja?',
    rl: 'Dotknij, aby ocenić',
    pt: 'Dziękujemy!',
    ps: 'Bylibyśmy wdzięczni, gdybyś podzielił się opinią, zostawiając recenzję w sklepie!',
    nt: 'Jak możemy ją ulepszyć?',
    ns: 'Twoja opinia pomaga nam się rozwijać.',
    rb: 'Oceń w sklepie',
    sb: 'Wsparcie & Współtwórz',
    eb: 'Wyślij nam e-mail',
  ),
  'pt': _LS(
    title: 'Quanto você gosta do app?',
    rl: 'Toque para avaliar',
    pt: 'Obrigado!',
    ps: 'Ficaríamos muito gratos se você pudesse compartilhar o amor deixando uma avaliação na loja!',
    nt: 'Como podemos melhorar?',
    ns: 'Seu feedback nos ajuda a melhorar.',
    rb: 'Avaliar na loja',
    sb: 'Suporte & Contribuir',
    eb: 'Envie-nos um e-mail',
  ),
  'ru': _LS(
    title: 'Насколько вам нравится приложение?',
    rl: 'Нажмите, чтобы оценить',
    pt: 'Спасибо!',
    ps: 'Будем благодарны, если вы поделитесь впечатлениями, оставив отзыв в магазине!',
    nt: 'Как мы можем улучшить?',
    ns: 'Ваш отзыв помогает нам становиться лучше.',
    rb: 'Оценить в магазине',
    sb: 'Поддержка & Вклад',
    eb: 'Отправить нам письмо',
  ),
  'ta': _LS(
    title: 'இந்த ஆப்ஸை நீங்கள் எவ்வளவு விரும்புகிறீர்கள்?',
    rl: 'மதிப்பிட தட்டவும்',
    pt: 'நன்றி!',
    ps: 'கடையில் மதிப்பாய்வை விட்டு அன்பைப் பகிர்ந்தால் நாங்கள் நன்றியுள்ளவர்களாக இருப்போம்!',
    nt: 'நாங்கள் அதை எப்படி மேம்படுத்தலாம்?',
    ns: 'உங்கள் கருத்து எங்களை மேம்படுத்த உதவுகிறது.',
    rb: 'கடையில் மதிப்பிடுங்கள்',
    sb: 'ஆதரவு & பங்களிப்பு',
    eb: 'எங்களுக்கு மின்னஞ்சல் அனுப்புங்கள்',
  ),
  'tr': _LS(
    title: 'Uygulamayı ne kadar beğendiniz?',
    rl: 'Değerlendirmek için dokun',
    pt: 'Teşekkürler!',
    ps: 'Mağazada bir yorum bırakarak sevginizi paylaşırsanız çok minnettar oluruz!',
    nt: 'Nasıl daha iyi hale getirebiliriz?',
    ns: 'Geri bildiriminiz gelişmemize yardımcı olur.',
    rb: 'Mağazada değerlendir',
    sb: 'Destek & Katkıda Bulun',
    eb: 'Bize e-posta gönderin',
  ),
  'uk': _LS(
    title: 'Наскільки вам подобається застосунок?',
    rl: 'Торкніться, щоб оцінити',
    pt: 'Дякуємо!',
    ps: 'Будемо вдячні, якщо ви поділитеся враженнями, залишивши відгук у магазині!',
    nt: 'Як ми можемо покращити?',
    ns: 'Ваш відгук допомагає нам ставати кращими.',
    rb: 'Оцінити в магазині',
    sb: 'Підтримка та внесок',
    eb: 'Надіслати нам лист',
  ),
  'vec': _LS(
    title: 'Quanto te piaze l\'app?',
    rl: 'Toca par valutar',
    pt: 'Grasie!',
    ps: 'Sarìsimo grati se te podessi condividar l\'amor lasando na recension inte el store!',
    nt: 'Come podemo mejorarlo?',
    ns: 'El to feedback ne juta a mejorar.',
    rb: 'Valuta inte el store',
    sb: 'Suporto & Contribuissi',
    eb: 'Màndane na email',
  ),
  'zh': _LS(
    title: '您有多喜欢这个应用？',
    rl: '点击评分',
    pt: '谢谢！',
    ps: '如果您能在商店留下评价，我们会非常感激！',
    nt: '我们如何做得更好？',
    ns: '您的反馈帮助我们改进。',
    rb: '在商店中评价',
    sb: '支持与贡献',
    eb: '给我们发送邮件',
  ),
};
