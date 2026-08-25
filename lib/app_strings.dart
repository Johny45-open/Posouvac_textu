class AppStrings {
  static bool isInformal = false;
  static Map<String, String> _customStrings = {};

  static const List<String> customStringKeys = [
    "welcomeTitle",
    "welcomeContent",
    "libraryTitle",
    "libraryContent",
    "playerTitle",
    "playerContent",
  ];

  static const Map<String, String> customStringKeyLabels = {
    "welcomeTitle": "Uvítání – nadpis",
    "welcomeContent": "Uvítání – text",
    "libraryTitle": "Knihovna – nadpis",
    "libraryContent": "Knihovna – text",
    "playerTitle": "Přehrávač – nadpis",
    "playerContent": "Přehrávač – text",
  };

  static const Map<String, String> customStringFormalDefaults = {
    "welcomeTitle": "Vítejte v Posouvači textů",
    "welcomeContent": "Tato aplikace vám pomůže s texty a akordy při hraní. Je navržena tak, aby byla plně přístupná pro čtečky obrazovky.",
    "libraryTitle": "Knihovna a import",
    "libraryContent": "V Knihovně najdete své písně. Nové texty ve formátu .txt importujete tlačítkem vpravo dole. Pokud chcete upravit jméno interpreta nebo název, podržte na písni prst déle.",
    "playerTitle": "Přehrávač a ovládání",
    "playerContent": "Klepnutím na text v přehrávači spustíte hlasový odpočet a automatický posuv. Všechny ovládací prvky (tempo, transpozice, velikost písma, rychlost posuvu) jsou nyní pohodlně umístěny v dolní části obrazovky pro snadný přístup. Pauzu přidáte krátkým klepnutím na tlačítko PAUZA, dlouhým podržením tohoto tlačítka otevřete jejich správu.",
  };

  static void setCustomStrings(Map<String, String> strings) {
    _customStrings = strings;
  }

  static String _getString(String key, String informal, String formal) {
    if (_customStrings.containsKey(key)) {
      return _customStrings[key]!;
    }
    return isInformal ? informal : formal;
  }

  // --- MANUÁL ---
  static String get welcomeTitle => _getString("welcomeTitle", "Čus muzikante!", "Vítejte v Posouvači textů");
  static String get welcomeContent => _getString("welcomeContent", 
    "Tenhle nástroj ti pohlídá texty i akordy, abys mohl v klidu válet. Všechno je nachystaný i pro čtečky obrazovky.",
    "Tato aplikace vám pomůže s texty a akordy při hraní. Je navržena tak, aby byla plně přístupná pro čtečky obrazovky.");

  static String get libraryTitle => _getString("libraryTitle", "Knihovna a tvý songy", "Knihovna a import");
  static String get libraryContent => _getString("libraryContent", 
    "Tady máš všechen svůj repertoár. Nový fláky v .txt tam hodíš tlačítkem vpravo dole. Když chceš něco upravit, stačí na tom songu podržet prst.",
    "V Knihovně najdete své písně. Nové texty ve formátu .txt importujete tlačítkem vpravo dole. Pokud chcete upravit jméno interpreta nebo název, podržte na písni prst déle.");

  static String get playerTitle => _getString("playerTitle", "Přehrávač a jízda", "Přehrávač a ovládání");
  static String get playerContent => _getString("playerContent", 
    "Klepni na text a odstartuješ odpočet i jízdu. Všechno ovládání (tempo, transpozici, velikost písma i rychlost) najdeš pohodlně dole. Když nestíháš, zpomal tempo o 5 BPM tlačítky v pravém horním rohu – fungují i během posuvu. Pauzu přidáš krátkým klepnutím, podržením je spravuješ. Pro pomalou píseň 75 až 90, pro rychlou 110 až 130 BPM.",
    "Klepnutím na text v přehrávači spustíte hlasový odpočet a automatický posuv. Všechny ovládací prvky (tempo, transpozice, velikost písma, rychlost posuvu) jsou nyní pohodlně umístěny v dolní části obrazovky pro snadný přístup. Pokud nestíháte zpívat, snižte tempo o 5 BPM tlačítky v pravém horním rohu – fungují i během posuvu. Pro pomalé písně doporučeno 75 až 90 BPM, pro rychlé 110 až 130 BPM. Pauzu přidáte krátkým klepnutím na tlačítko PAUZA, dlouhým podržením tohoto tlačítka otevřete jejich správu.");

  // --- BPM OVERLAY (rychlé ladění tempa i během posuvu) ---
  static String get bpmOverlayDecreaseLabel => isInformal ? "Zpomalit o 5 BPM" : "Zpomalit o 5 BPM";
  static String get bpmOverlayIncreaseLabel => isInformal ? "Zrychlit o 5 BPM" : "Zrychlit o 5 BPM";
  static String get bpmOverlayDecreaseLongLabel => isInformal ? "Zpomalit o 10 BPM (podrž)" : "Zpomalit o 10 BPM (podržení)";
  static String get bpmOverlayIncreaseLongLabel => isInformal ? "Zrychlit o 10 BPM (podrž)" : "Zrychlit o 10 BPM (podržení)";
  static String bpmOverlayValue(int bpm) => "$bpm BPM";
  static String bpmEffectiveValue(int effective) => "Efektivně $effective BPM";
  static String get bpmOverlaySemantics => isInformal ? "Ovládání tempa, aktuálně" : "Ovládání tempa, aktuální hodnota";
  static String bpmChangedMessage(int bpm) => isInformal ? "Tempo $bpm BPM" : "Tempo $bpm BPM";
  static String get bpmOverlayHelp => isInformal
      ? "Když nestíháš, klepni na mínus, zpomalíš o 5 BPM i během posuvu. Podržením o 10. Pro pomalou 75 až 90, pro rychlou 110 až 130. Pauzu přidáš PAUZOU na začátek sloky."
      : "Pokud nestíháte, klepněte na minus – tempo se sníží o 5 BPM i během posuvu (podržením o 10). Pro pomalé 75 až 90, pro rychlé 110 až 130 BPM. Pauzu přidáte PAUZOU na začátek sloky.";

  // ... (a tak dále pro všechny ostatní metody, ale pro stručnost zde jen hlavní princip)
  static String get extraTitle => isInformal ? "Ladička a setlisty" : "Ladička a setlisty";
  static String get extraContent => isInformal 
      ? "Naladíš se přes tu notu v knihovně. A přes plusko si songy naházíš do setlistů, třeba na dnešní oslavu."
      : "Ikona noty v Knihovně otevře ladičku. Ikona plus u písně vám umožní zařadit ji do vlastních seznamů, jako jsou například setlisty Olympic nebo Oslava.";

  static String get accessibilityTitle => isInformal ? "Tipy pro nevidomý" : "Informace pro nevidomé";
  static String get accessibilityContent => isInformal 
      ? "Aplikace s TalkBackem spolupracuje na jedničku. V přehrávači stačí klepnout kamkoliv do textu a jízda začne. Setlist režim tě provede celým koncertem úplně sám, stačí jen hrát. Všechna tlačítka mají svůj popisek, takže se neztratíš."
      : "Aplikace je plně přístupná se čtečkou obrazovky. V přehrávači aktivujete posuv poklepáním na text písně. Režim Setlist automaticky přepíná písně a hlásí jejich názvy. Všechny ovládací prvky jsou popsány pro snadnou orientaci šviháním prstem.";

  static String get understandButton => isInformal ? "JASNÝ, JDU NA TO!" : "ROZUMÍM";

  // --- KNIHOVNA ---
  static String get importTypeTitle => isInformal ? "Jak to tam naházíme?" : "Jak chcete importovat?";
  static String get importTypeContent => isInformal 
      ? "Výběr jednotlivejch souborů je u starších strojů jistota." 
      : "Výběr souborů je spolehlivější na starších zařízeních a tabletech.";
  
  static String get importStarted => isInformal ? "Jdu na to, skenuju texty..." : "Importuji texty...";
  static String get importDialogTitle => isInformal ? "Tlačím to tam..." : "Importuji texty";
  
  static String importFinished(int count) => 
      isInformal ? "Hotovo! Máš tam $count novejch kousků." : "Import dokončen. Bylo přidáno $count nových písní.";
      
  static String get noNewSongs => 
      isInformal ? "Tohle už všechno v seznamu máš." : "Všechny vybrané soubory již v knihovně máte.";

  static String songMarkedFavorite(String title) => 
      isInformal ? "Pecka! $title je v oblíbených." : "Skladba $title byla označena jako oblíbená.";
  
  static String songRemovedFavorite(String title) => 
      isInformal ? "$title už v oblíbených není." : "Skladba $title byla odebrána z oblíbených.";

  static String get filterFavorites => 
      isInformal ? "Teď vidíš jen svý nejlepší kousky." : "Nyní se filtrují pouze oblíbené skladby.";
  static String get filterUnplayed => 
      isInformal ? "Vidíš jen to, co zbejvá odehrát. Jdeme na to!" : "Nyní se filtrují neodehrané skladby.";
  static String get filterAll => 
      isInformal ? "Tady je kompletní nálož všech písní." : "Nyní se zobrazují všechny skladby.";

  static String get resetPlayed => 
      isInformal ? "Jdeme na to od nuly, všechno vyčištěno." : "Evidence odehraných skladeb byla vynulována.";

  // --- PŘEHRÁVAČ ---
  static String get bpmDialogTitle => isInformal ? "Jak je to rychle?" : "Nastavit tempo (BPM)";
  static String get tapTempoButton => isInformal ? "KLEPEJ SEM DO RYTMU" : "KLEPEJTE DO RYTMU";
  
  static String songMarkedPlayed(String title) => 
      isInformal ? "A je to, $title odškrtnuto." : "Skladba $title byla označena jako odehraná.";

  static String songMarkedNotPlayed(String title) => 
      isInformal ? "$title si dáme ještě jednou!" : "Skladba $title byla vrácena do seznamu k odehrání.";

  static String get playedButton => isInformal ? "ODEHRÁNO" : "ODEHRÁNO";
  static String get encoreButton => isInformal ? "PŘÍDAVEK!" : "PŘÍDAVEK";

  // --- SETLIST A ODPOČET ---
  static String introMessage(int seconds) => 
      isInformal ? "Intro $seconds sekund, nachystej se!" : "Intro $seconds sekund.";
  
  static String stopMarkMessage(int bars) => 
      isInformal ? "Pauza na $bars takty, vydechni si." : "Pauza na $bars takty.";

  static String get stopMarkQuickAdded => 
      isInformal ? "Zarážka je tam!" : "Zarážka byla přidána.";

  static String get stopMarkResumeMessage => 
      isInformal ? "A jedem!" : "Pokračujeme.";

  static String get addStopMarkButtonLabel => 
      isInformal ? "Zarážka na viditelný řádek" : "Přidat zarážku na viditelný řádek";

  static String nextSongMessage(String title, String artist) => 
      isInformal ? "Teď dáme $title od $artist, jdeme na to!" : "Následuje píseň $title od interpreta $artist.";

  static String get setlistEndMessage => 
      isInformal ? "A je to! Celý setlist dohrán, seš borec!" : "Konec setlistu. Všechny skladby byly odehrány.";

  static String startSetlistMessage(String name, String firstSong) => 
      isInformal ? "Rozjíždíme setlist $name. První flák je $firstSong." : "Spouštím setlist $name. První píseň je $firstSong.";

  // --- PLAYLISTY / SETLISTY ---
  static String playlistCreated(String name) => 
      isInformal ? "Setlist $name je na světě." : "Setlist $name byl vytvořen.";
  
  static String playlistDeleted(String name) => 
      isInformal ? "Smazáno. Setlist $name už neexistuje." : "Setlist $name byl smazán.";

  static String playlistRenamed(String oldName, String newName) => 
      isInformal ? "Přejmenováno z $oldName na $newName." : "Setlist $oldName byl přejmenován na $newName.";

  static String songRemovedFromPlaylist(String title) => 
      isInformal ? "Song $title ze setlistu vyletěl." : "Skladba $title byla odebrána ze setlistu.";

  static String get bulkAddTitle => isInformal ? "Co tam přihodíme?" : "Vybrat písně do setlistu";
  static String bulkAddFinished(int count) => 
      isInformal ? "Přidáno $count kousků. To bude jízda!" : "Do setlistu bylo úspěšně přidáno $count skladeb.";

  // --- SDRÍLENÝ IMPORT PLAYLISTU ---
  static String playlistImportSuccess(String name, int matched) =>
      isInformal ? "Setlist $name nahrán, přiřazeno $matched písní."
                 : "Setlist $name byl importován, bylo přiřazeno $matched písní.";

  static String playlistImportMissing(int missing) =>
      isInformal ? "Celkem $missing se v knihovně nenašlo, ty vynechávám."
                 : "$missing písní nebylo v knihovně nalezeno a byly vynechány.";

  static String get playlistImportError =>
      isInformal ? "Tohle se jako setlist načíst nedá, zkontroluj přijatá data."
                 : "Nepodařilo se načíst platný setlist z přijatých dat.";

  static String get playlistImportChoiceTitle => isInformal ? "Odkud setlist vzít?" : "Importovat setlist z...";
  static String get playlistImportFileLabel => isInformal ? "Ze souboru" : "Ze souboru";
  static String get playlistImportFileDescription => isInformal ? "JSON nebo HTML soubor" : "Importovat setlist ze souboru (JSON/HTML)";
  static String get playlistImportHtmlLabel => isInformal ? "HTML přehled" : "HTML přehled";
  static String get playlistImportHtmlDescription => isInformal ? "Soubor vygenerovaný v prohlížeči" : "Importovat z HTML přehledu";
  static String get playlistImportClipboardLabel => isInformal ? "Ze schránky" : "Ze schránky";
  static String get playlistImportClipboardDescription => isInformal ? "Vložit text zkopírovaný odjinud" : "Importovat ze schránky (text)";
  static String get playlistImportClipboardEmpty => isInformal ? "Schránka je prázdná" : "Schránka je prázdná";
  static String get playlistImportHtmlSuccess => isInformal ? "Setlist z HTML nahraný." : "Setlist z HTML byl úspěšně importován.";
  static String get playlistImportHtmlError => isInformal ? "Z toho HTML se setlist načíst nedá." : "Nepodařilo se importovat setlist z HTML.";

  // --- SDÍLENÍ SETLISTU S ČASEM (v2) ---
  static String get sharePlaylistTitle => isInformal ? "Jak setlist pošleš?" : "Sdílet setlist";
  static String get sharePlaylistHtmlLabel => isInformal ? "HTML soubor" : "HTML soubor";
  static String get sharePlaylistHtmlDescription => isInformal
      ? "Tabulka s názvy a časy. Otevře se v prohlížeči i bez internetu."
      : "Tabulka s pořadím, interprety a časy. Otevře se v libovolném prohlížeči offline.";
  static String sharePlaylistHtmlText(String name) => isInformal
      ? "Setlist $name – přehled s časy"
      : "Setlist $name – přehled s časy (HTML)";
  static String get sharePlaylistHtmlDone => isInformal
      ? "Soubor setlistu je připraven, vyber kam ho pošleš."
      : "Soubor setlistu je připraven. Vyberte, kam jej chcete odeslat.";
  static String get sharePlaylistPackageLabel => isInformal ? "Balíček setlistu" : "Balíček setlistu";
  static String get sharePlaylistPackageDescription => isInformal
      ? "Jenom názvy a časy. Stačí když má příjemce písně v knihovně."
      : "Obsahuje názvy, interprety a časy. Příjemce musí mít písně v knihovně.";
  static String get sharePlaylistWithContentsLabel => isInformal ? "Balíček včetně textů" : "Balíček včetně textů";
  static String get sharePlaylistWithContentsDescription => isInformal
      ? "I s texty a akordy. Větší soubor, ale příjemce nemusí mít písně."
      : "Obsahuje i texty a akordy. Větší soubor, ale funguje i bez knihovny.";
  static String sharePlaylistPackageText(String name) => isInformal
      ? "Setlist $name pro Posouvač textu"
      : "Setlist $name – balíček pro Posouvač textu";
  static String get sharePlaylistPackageDone => isInformal
      ? "Balíček setlistu je připraven, vyber kam ho pošleš."
      : "Balíček setlistu je připraven. Vyberte, kam jej chcete odeslat.";
  static String get sharePlaylistQrLabel => isInformal ? "QR kód" : "QR kód";
  static String get sharePlaylistQrDescription => isInformal
      ? "Pro menší setlisty. Naskenuje se kamerou bez internetu."
      : "Pro menší setlisty. Naskenuje se kamerou a funguje offline.";
  static String get sharePlaylistQrTooLong => isInformal
      ? "Setlist je moc velký na QR kód, použij balíček nebo HTML soubor."
      : "Setlist je příliš velký pro QR kód. Použijte prosím balíček nebo HTML soubor.";
  static String get sharePlaylistQrDialogTitle => isInformal ? "QR kód se setlistem" : "QR kód se setlistem";
  static String sharePlaylistQrSemantics(String name) => isInformal
      ? "QR kód se setlistem $name. Obsah je zobrazen níže jako tabulka."
      : "QR kód se setlistem $name. Obsah je zobrazen níže jako tabulka.";
  static String playlistShareTimeSemantics(int totalSec, int unknown) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    final base = unknown == 0 ? "$m minut $s sekund" : "$m minut $s sekund plus $unknown bez času";
    return base;
  }
  static String get playlistFixDialogTitle => isInformal ? "Doplnit chybějící údaje?" : "Doplnit chybějící údaje?";
  static String playlistFixDialogContent(int timeCount, int diaCount) {
    final parts = <String>[];
    if (timeCount > 0) parts.add(isInformal ? "u $timeCount písní chybí čas" : "u $timeCount písní chybí čas");
    if (diaCount > 0) parts.add(isInformal ? "u $diaCount opravit háčky a čárky" : "u $diaCount opravit diakritiku");
    return "V setlistu ${parts.join(" a ")}. Chcete je doplnit podle sdíleného setlistu?";
  }
  static String playlistFixTimeItem(String artist, String title, String duration) =>
      isInformal ? "$artist – $title: doplnit $duration" : "$artist – $title: doplnit $duration";
  static String playlistFixDiaItem(String oldA, String oldT, String newA, String newT) =>
      "$oldA – $oldT → $newA – $newT";
  static String get playlistFixConfirmLabel => isInformal ? "Doplnit" : "Doplnit";
  static String get playlistFixSkipLabel => isInformal ? "Ponechat" : "Ponechat";
  static String playlistFixDone(int timeFixed, int diaFixed) {
    final parts = <String>[];
    if (timeFixed > 0) parts.add(isInformal ? "$timeFixed časů" : "$timeFixed časů");
    if (diaFixed > 0) parts.add(isInformal ? "$diaFixed názvů" : "$diaFixed názvů");
    return isInformal ? "Doplněno ${parts.join(" a ")}." : "Doplněno ${parts.join(" a ")}.";
  }
  static String get playlistExportEmpty => isInformal ? "Setlist je prázdný, není co sdílet." : "Setlist je prázdný, není co sdílet.";
  static String playlistImportWithTime(String name, int matched, String timeText) =>
      isInformal ? "Setlist $name nahrán, $matched písní, $timeText." : "Setlist $name importován, $matched písní, $timeText.";

  // --- SETLIST PRODLEVA ---
  static String get setlistDelayTitle => isInformal ? "Prodleva mezi písněmi" : "Prodleva mezi písněmi v setlistu";
  static String get setlistDelaySubtitle => isInformal
      ? "Jak dlouho čekat než skočí další flák"
      : "Jak dlouho čekat před automatickým přechodem na další píseň";
  static String get setlistDelay3 => "3 sekundy";
  static String get setlistDelay5 => "5 sekund";
  static String get setlistDelay10 => "10 sekund";
  static String get setlistDelayWait => isInformal ? "Čekat na poklep" : "Čekat na stisk";
  static String setlistDelayAnnouncement(int delay) => delay < 0
      ? (isInformal ? "Prodleva: čekat na poklep" : "Prodleva: čekat na stisk")
      : (isInformal ? "Prodleva $delay sekund" : "Prodleva $delay sekund");
  static String get setlistNextReady => isInformal
      ? "Připravena další píseň. Klepni kamkoliv, stiskni pedál nebo mezerník pro start."
      : "Připravena další píseň. Klepněte kamkoliv, stiskněte pedál nebo mezerník pro spuštění.";
  static String setlistPositionAnnouncement(int current, int total) =>
      isInformal ? "Skladba $current z $total v setlistu" : "Skladba $current z $total v setlistu";
  static String setlistNextSongAnnouncement(String title, String artist) =>
      isInformal ? "Další v setlistu: $title od $artist" : "Další v setlistu: $title od $artist";
  static String setlistPrevSongAnnouncement(String title, String artist) =>
      isInformal ? "Předchozí v setlistu: $title od $artist" : "Předchozí v setlistu: $title od $artist";
  static String get setlistSkipNextLabel => isInformal ? "Další píseň v setlistu" : "Další píseň v setlistu";
  static String get setlistSkipPrevLabel => isInformal ? "Předchozí píseň v setlistu" : "Předchozí píseň v setlistu";
  static String get setlistCancelAutoLabel => isInformal ? "Zrušit automatický přechod" : "Zrušit automatický přechod";

  // --- SETLIST ČAS NEZNÁMÝ / ODHAD ---
  static String setlistTimeWithUnknown(String timeText, int unknown) => unknown == 0
      ? timeText
      : (isInformal
          ? "$timeText plus $unknown bez času (tip ~${unknown * 3} min navíc)"
          : "$timeText plus $unknown bez času (odhad +${unknown * 3} min)");
  static String setlistUnknownAnnouncement(int unknown) => isInformal
      ? "U $unknown písní čas neznám, odhad je podhodnocený"
      : "U $unknown písní čas neznám, odhad je podhodnocený";
  static String get songDurationUnknown => isInformal ? "Délka neznámá" : "Délka neznámá";
  static String songDurationEstimateHint(int estMin) => isInformal
      ? "Tip: odhad asi $estMin minuty"
      : "Tip: odhad asi $estMin minuty";
  static String songDurationUnknownSemantics(String title) => isInformal
      ? "Délka neznámá, odhad asi 3 minuty. Poklepáním na Upravit doplňte přesný čas písně $title"
      : "Délka neznámá, odhad asi 3 minuty. V Knihovně doplňte přesný čas písně $title";
  static String get setlistReadOrderLabel => isInformal ? "Přečíst pořadí setlistu" : "Přečíst pořadí setlistu";
  static String get setlistReadOrderTooltip => isInformal ? "Přečíst celé pořadí setlistu" : "Přečíst celé pořadí setlistu";
  static String setlistReadOrderAnnouncement(List<String> titles) =>
      isInformal ? "Pořadí setlistu: ${titles.join(", ")}" : "Pořadí setlistu: ${titles.join(", ")}";
  static String get setlistUnlockReorderLabel => isInformal ? "Odemknout přesouvání šipkami" : "Odemknout přesouvání šipkami";
  static String get setlistLockReorderLabel => isInformal ? "Zamknout přesouvání" : "Zamknout přesouvání";
  static String get setlistUnlockConfirmTitle => isInformal ? "Odemknout přesouvání?" : "Odemknout přesouvání?";
  static String get setlistUnlockConfirmContent => isInformal
      ? "Na pódiu hrozí nechtěná změna pořadí dotykem v kapse. Opravdu odemknout šipky?"
      : "Na pódiu hrozí nechtěná změna pořadí dotykem. Opravdu odemknout šipky pro přesouvání?";
  static String get setlistReorderUnlockedAnnouncement => isInformal ? "Přesouvání odemknuto" : "Přesouvání šipkami odemknuto";
  static String get setlistReorderLockedAnnouncement => isInformal ? "Přesouvání zamknuto" : "Přesouvání šipkami zamknuto";

  // --- SDÍLENÍ PÍSNĚ ---
  static String get shareTitle => isInformal ? "Komu text pošleš?" : "Sdílet text písně";
  static String get shareButtonLabel =>
      isInformal ? "Sdílet text písně" : "Sdílet text písně";

  static String get shareHtmlLabel => isInformal ? "HTML soubor" : "HTML soubor";
  static String get shareHtmlDescription => isInformal
      ? "Pro zpěváka bez aplikace. Otevře se v prohlížeči i bez internetu."
      : "Pro zpěváka bez aplikace. Otevře se v libovolném prohlížeči a funguje offline.";
  static String shareHtmlText(String title) => isInformal
      ? "Text písně $title pro prohlížeč"
      : "Text písně $title (HTML, funguje offline)";
  static String get shareHtmlDone => isInformal
      ? "Soubor je připraven, vyber, kam ho pošleš."
      : "Soubor je připraven. Vyberte, kam jej chcete odeslat.";

  static String get shareQrLabel => isInformal ? "QR kód" : "QR kód";
  static String get shareQrDescription => isInformal
      ? "Pro kratší texty. Naskenuje se kamerou bez internetu."
      : "Pro kratší texty. Naskenuje se kamerou a funguje offline.";
  static String get shareQrTooLong => isInformal
      ? "Text je moc dlouhý na QR kód, použij HTML soubor nebo balíček písně."
      : "Text je příliš dlouhý pro QR kód. Použijte prosím HTML soubor nebo balíček písně.";
  static String get shareQrDialogTitle =>
      isInformal ? "Naskenuj QR nebo si přečti text" : "QR kód s textem písně";
  static String shareQrSemantics(String title, String artist) => isInformal
      ? "QR kód s textem písně $title od $artist. Celý text je zobrazen níže."
      : "QR kód s textem písně $title od interpreta $artist. Celý text je zobrazen níže.";
  static String get shareQrTextLabel =>
      isInformal ? "Text písně:" : "Text písně:";

  static String get sharePackageLabel => isInformal ? "Balíček písně" : "Balíček písně";
  static String get sharePackageDescription => isInformal
      ? "Pro zpěváka, co má aplikaci. Text mu spadne rovnou do knihovny."
      : "Pro zpěváka s aplikací. Text se naimportuje přímo do jeho knihovny.";
  static String sharePackageText(String title) => isInformal
      ? "Píseň $title pro Posouvač textu"
      : "Píseň $title - balíček pro Posouvač textu";
  static String get sharePackageDone => isInformal
      ? "Balíček je připraven, vyber, kam ho pošleš."
      : "Balíček písně je připraven. Vyberte, kam jej chcete odeslat.";

  static String get shareFileMissing => isInformal
      ? "Text souboru se nepodařilo načíst."
      : "Text písně se nepodařilo načíst.";
  static String get shareError =>
      isInformal ? "Tohle sdílení se nepovedlo." : "Sdílení se nezdařilo.";

  static String songImportSuccess(String title) => isInformal
      ? "Píseň $title je v knihovně!"
      : "Píseň $title byla přidána do knihovny.";
  static String songImportExists(String title) => isInformal
      ? "Píseň $title už v knihovně máš."
      : "Píseň $title je již ve vaší knihovně.";
  static String get songImportError => isInformal
      ? "Tohle se jako píseň načíst nedá, zkontroluj přijatá data."
      : "Nepodařilo se načíst píseň z přijatých dat.";

  // --- SKENER QR KÓDŮ ---
  static String get scanQrTooltip => isInformal ? "Naskenovat QR kód" : "Naskenovat QR kód";
  static String get scanQrPageTitle => isInformal ? "Skener QR kódu" : "Skener QR kódů";
  static String get scanQrInstruction => isInformal
      ? "Namiř foťák na QR kód a píseň ti spadne rovnou do knihovny."
      : "Namiřte fotoaparát na QR kód. Naskenovaná píseň se přidá do knihovny.";
  static String get scanQrPermissionError => isInformal
      ? "Bez povoleného foťáku to nejde. Povol kameře přístup v nastavení."
      : "Skenování vyžaduje přístup k fotoaparátu. Povolte jej prosím v nastavení aplikace.";
  static String get scanPlainDialogTitle =>
      isInformal ? "Co je to za píseň?" : "Název naskenovaného textu";
  static String get scanPlainDialogText => isInformal
      ? "Ten QR kód neobsahuje název ani interpreta, jen text. Doplň je, ať se ti píseň líp najde."
      : "Naskenovaný QR kód obsahuje pouze text bez názvu. Doplňte prosím název a interpreta.";
  static String get scanPlainTitleLabel => "Název písně";
  static String get scanPlainArtistLabel => "Jméno interpreta";
  static String get scanPlainPreviewLabel => isInformal ? "Text písně:" : "Text písně:";
  static String get scanPlainDefaultTitle => "Naskenovaná píseň";
  static String get scanPlainDefaultArtist => "Neznámý interpret";


  // --- NASTAVENÍ A ZÁLOHA ---
  static String get settingsTitle => isInformal ? "Vychytávky" : "Nastavení";
  static String get backupTitle => isInformal ? "Záloha dat" : "Zálohování a obnova";
  static String get backupExportButton => isInformal ? "Uložit všechno do souboru" : "Vytvořit zálohu (Export)";
  static String get backupImportButton => isInformal ? "Nahrát data ze zálohy" : "Obnovit ze zálohy (Import)";
  static String get backupExportSuccess => isInformal ? "Všechno je v bezpečí, záloha hotová." : "Záloha byla úspěšně vytvořena.";
  static String get backupImportSuccess => isInformal ? "Data jsou zpátky, můžeš hrát!" : "Data byla úspěšně obnovena ze zálohy.";
  static String get backupImportWarning => isInformal 
      ? "Bacha! Tohle smaže tvý aktuální písničky a nahradí je těma ze zálohy. Chceš to fakt udělat?" 
      : "Upozornění: Obnovení ze zálohy nahradí veškerá vaše aktuální data daty ze souboru. Přejete si pokračovat?";

  // --- NASTAVENÍ ---

  static String get themeLight => isInformal ? "Budiž světlo." : "Světlý motiv nastaven.";
  static String get themeDark => isInformal ? "Tma je tu." : "Tmavý motiv nastaven.";
  static String get themeSystem => isInformal ? "Systém rozhodne za nás." : "Systémový motiv nastaven.";

  // --- AKTUALIZACE ---
  static String get updateCheckTile => isInformal ? "Zkontrolovat aktualizace" : "Zkontrolovat aktualizace";
  static String get updateCheckTileSubtitle => isInformal
      ? "Jestli je venku novější verze"
      : "Ověřit, zda je dostupná nová verze aplikace";
  static String get updateNewsTile => isInformal ? "Co je nového" : "Co je nového";
  static String get updateNewsTileSubtitle => isInformal
      ? "Projít kompletní historii verzí"
      : "Zobrazit kompletní historii verzí od první po poslední";
  static String get updateChecking => isInformal ? "Koukám na GitHub..." : "Kontroluji dostupnost aktualizací...";
  static String get updateHistoryTitle => isInformal ? "Historie verzí" : "Historie verzí";
  static String get updateHistoryEmpty => isInformal
      ? "Žádný poznámky k verzím nejsou."
      : "Pro žádnou verzi nejsou k dispozici poznámky.";
  static String get updateAvailableTitle => isInformal ? "Je tu nová verze!" : "Nová verze je k dispozici";
  static String updateAvailableMessage(String version) => isInformal
      ? "Vyšla verze $version. Chceš kouknout, co je novýho?"
      : "Byla vydána verze $version. Přejete si zobrazit podrobnosti a stáhnout ji?";
  static String get updateNewsTitle => isInformal ? "Co je novýho:" : "Novinky:";
  static String get updateUpToDate => isInformal
      ? "Všechno je aktuální, jede se dál!"
      : "Máte aktuální verzi aplikace.";
  static String get updateCheckError => isInformal
      ? "Kontrola se nepovedla, skontroluj připojení k internetu."
      : "Kontrolu aktualizací se nepodařilo dokončit. Zkontrolujte prosím připojení k internetu.";
  static String get updateOpenButton => isInformal ? "Otevřít na GitHubu" : "Zobrazit na GitHubu";
  static String get updateCloseButton => isInformal ? "Zavřít" : "Zavřít";
  static String get updateRefreshTooltip => isInformal ? "Načíst znovu" : "Obnovit historii verzí";
  static String get updateHistoryRefreshed => isInformal
      ? "Historie je aktuální."
      : "Historie verzí byla aktualizována.";
  static String get progressCancelButton => isInformal ? "Zrušit" : "Zrušit";
  static String get updateTimeoutTitle => isInformal ? "To trvá moc dlouho" : "Kontrola trvá příliš dlouho";
  static String get updateCheckTimeout => isInformal
      ? "Aktualizace se nemohly zkontrolovat, internet je moc pomalej. Zkus to znovu."
      : "Kontrolu aktualizací se nepodařilo dokončit v časovém limitu. Zkontrolujte připojení k internetu a zkuste to znovu.";
  static String get retryButton => isInformal ? "Zkusit znovu" : "Zkusit znovu";
  static String get historyLoadOlderButton => isInformal ? "Načíst starší verze" : "Načíst starší verze";
  static String get newsReadTooltip => isInformal ? "Přečíst novinky k verzi" : "Přečíst novinky k této verzi";
  static String get newsReadAllTooltip => isInformal ? "Přečíst všechny novinky" : "Přečíst všechny novinky";
  static String get newsStopTooltip => isInformal ? "Přestat číst" : "Zastavit čtení";
  static String newsVersionSpoken(String version) => isInformal ? "Verze $version." : "Verze $version.";

  // --- KONTROLA KNIHOVNY ---
  static String get libraryCheckTile => isInformal ? "Zkontrolovat knihovnu" : "Zkontrolovat knihovnu";
  static String get libraryCheckSubtitle => isInformal
      ? "Srovnej názvy písniček s txt soubory"
      : "Porovnat názvy písní v databázi s txt soubory a opravit neshody";
  static String get libraryCheckRunning => isInformal ? "Kontroluju knihovnu..." : "Kontroluji knihovnu...";
  static String get libraryCheckOk => isInformal
      ? "Všechno sedí, žádný rozdíly jsem nenašel."
      : "Knihovna je v pořádku, žádné neshody nebyly nalezeny.";
  static String libraryCheckFound(int count) => isInformal
      ? "Našel jsem $count rozdíly mezi databází a souborama."
      : "Nalezeno $count neshod mezi databází a txt soubory.";
  static String get libraryCheckRepairButton => isInformal ? "Opravit vše" : "Opravit vše";
  static String get libraryCheckCloseButton => isInformal ? "Zavřít" : "Zavřít";
  static String libraryCheckRepaired(int count) => isInformal
      ? "Hotovo, opravil jsem $count písniček."
      : "Opraveno $count písní.";
  static String get libraryCheckFileMissing => isInformal ? "Soubor nenalezen" : "Soubor nenalezen";
  static String get libraryCheckRepairFailed => isInformal
      ? "Oprava se nepovedla."
      : "Opravu se nepodařilo dokončit.";

  // --- IMPORT TXT SOUBORŮ ---
  static String importExistingFound(int count) => isInformal
      ? "$count souborů už v knihovně mám. Mám přepsat jejich názvy podle souborů?"
      : "$count vybraných souborů již v knihovně existuje. Aktualizovat jejich názvy a interprety podle obsahu souborů?";
  static String get importUpdateExistingButton => isInformal ? "Aktualizovat" : "Aktualizovat existující";
  static String get importSkipExistingButton => isInformal ? "Jen nový" : "Pouze nové";
  static String get importCancelQuestionButton => isInformal ? "Zrušit" : "Zrušit";
  static String importFinishedMixed(int added, int updated) => isInformal
      ? "Přidáno $added novejch, aktualizováno $updated písniček."
      : "Přidáno $added nových písní, aktualizováno $updated písní.";
  static String importUpdatedOnly(int count) => isInformal
      ? "Aktualizoval jsem $count písniček."
      : "Aktualizováno $count písní.";

  // --- KONCERTNÍ REŽIM ---
  static String get concertModeTitle => isInformal ? "Koncertní režim" : "Koncertní režim";
  static String get concertModeSubtitleOn => isInformal
      ? "Zapnuto - velké plochy, pedál, volume, náhled do sluchátka"
      : "Zapnuto - velké dotykové plochy, pedál, volume tlačítka, náhled do sluchátka";
  static String get concertModeSubtitleOff => isInformal
      ? "Vypnuto - klasické ovládání"
      : "Vypnuto - klasické ovládání";
  static String get concertModeAnnouncementOn => isInformal ? "Koncertní režim zapnut" : "Koncertní režim zapnut";
  static String get concertModeAnnouncementOff => isInformal ? "Koncertní režim vypnut" : "Koncertní režim vypnut";

  static String get concertPreviewModeTitle => isInformal ? "Ohlašovat další řádek" : "Ohlašování dalšího řádku";
  static String get concertPreviewOff => isInformal ? "Vypnuto" : "Vypnuto";
  static String get concertPreviewOnDemand => isInformal ? "Na vyžádání" : "Na vyžádání";
  static String get concertPreviewAuto => isInformal ? "Automaticky" : "Automaticky";
  static String get concertPreviewOnDemandHint => isInformal
      ? "Pedál podržet, 2 prsty poklepat nebo headset tlačítko - řekne další řádek"
      : "Podržením pedálu, poklepáním dvěma prsty nebo tlačítkem headsetu";
  static String get concertPreviewAutoHint => isInformal
      ? "Sám ohlásí další řádek 2,5 sekundy předem - vhodné s jedním sluchátkem"
      : "Automaticky ohlásí další řádek 2,5 sekundy předem - vhodné s jedním sluchátkem";
  static String get concertPreviewOffHint => isInformal
      ? "Řádky se samy neohlášují, můžeš si je říct ručně"
      : "Vypnuto - další řádek se automaticky neohlášuje";

  static String get concertZonesModeTitle => isInformal ? "Zónové ovládání" : "Zónové ovládání obrazovky";
  static String get concertZonesAlways => isInformal ? "Pořád aktivní" : "Vždy aktivní";
  static String get concertZonesOnDemand => isInformal ? "Na požádání" : "Na požádání";
  static String get concertZonesAlwaysHint => isInformal
      ? "Zóny reagujou na dotik hned, jak je znáš"
      : "Zóny reagují na dotyky okamžitě - dosavadní chování";
  static String get concertZonesOnDemandHint => isInformal
      ? "Nejdřív nic nedělaj, zapneš je tlačítkem v přehrávači"
      : "Zóny nejdřív nereagují. Zapnete je tlačítkem v přehrávači";

  static String get zoneToggleArmLabel => isInformal ? "Zapnout zóny" : "Zapnout zónové ovládání";
  static String get zoneToggleDisarmLabel => isInformal ? "Vypnout zóny" : "Vypnout zónové ovládání";
  static String get zonesArmedAnnouncement => isInformal ? "Zóny jsou živý!" : "Zónové ovládání zapnuto";
  static String get zonesDisarmedAnnouncement => isInformal
      ? "Zóny vypnutý, text si můžeš klidně projet prstem."
      : "Zónové ovládání vypnuto.";

  // --- NÁHLED DALŠÍHO ŘÁDKU ---
  static String nextLineAnnouncement(String text) => isInformal ? "Další: $text" : "Další: $text";
  static String nextLineWithChords(String chords, String text) => isInformal
      ? "Další: $chords, $text"
      : "Další: $chords, $text";
  static String nextSectionAnnouncement(String section) => isInformal ? "$section" : "$section";
  static String get nextLineEmpty => isInformal ? "Konec textu" : "Konec textu";
  static String get nextLineGestureHint => isInformal
      ? "Dvojitým poklepáním dvěma prsty zjistíš další řádek"
      : "Dvojitým poklepáním dvěma prsty ohlašte další řádek";
  static String get concertZoneLeftSemantics => isInformal ? "Zpomalit o 5 BPM, levá třetina" : "Zpomalit o 5 BPM";
  static String get concertZoneCenterSemantics => isInformal ? "Spustit nebo zastavit posuv, střed" : "Spustit nebo zastavit posuv";
  static String get concertZoneRightSemantics => isInformal ? "Zrychlit o 5 BPM, pravá třetina" : "Zrychlit o 5 BPM";
  static String get concertZoneNextLineSemantics => isInformal ? "Ohlásit další řádek" : "Ohlásit další řádek";

  // --- HLASOVÁ OHLÁŠENÍ PŘEHRÁVAČE ---
  static String fontSizeChanged(int size) => isInformal ? "Písmo $size" : "Písmo $size";
  static String scrollSpeedChanged(int percent) => isInformal
      ? "Rychlost posuvu $percent procent"
      : "Rychlost posuvu $percent procent";
  static String bpmSetMessage(int bpm) => isInformal
      ? "Nastaveno $bpm BPM"
      : "Nastaveno $bpm BPM";
  static String get scrollStopped => isInformal ? "Stavím to!" : "Posuv zastaven";

  // --- VÝVOJÁŘSKÝ REŽIM ---
  static String get devModeOnAnnouncement => isInformal ? "Vývojářskej režim je vzhůru!" : "Vývojářský režim zapnut";
  static String pinIncorrect(int remaining) => remaining <= 1
      ? (isInformal ? "PIN nesedí, tohle byl poslední pokus." : "Nesprávný PIN, zbývá poslední pokus.")
      : (isInformal ? "PIN nesedí, máš ještě $remaining pokusy." : "Nesprávný PIN, zbývá $remaining pokusů.");
  static String get pinEmpty => "PIN nesmí být prázdný";
  static String get pinTooShort => isInformal ? "PIN musí mít aspoň 4 číslice" : "PIN musí mít alespoň 4 číslice";
  static String get pinMismatch => isInformal ? "Zadaný PINy se neshodujou" : "Zadané PINy se neshodují";
  static String pinLockout(int minutes) => isInformal
      ? "To je moc pokusů. Zkus to za $minutes minuty."
      : "Přístup do vývojářského režimu je na $minutes minut zamčen.";
}
