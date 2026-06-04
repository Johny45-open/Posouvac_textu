class AppStrings {
  static bool isInformal = false;

  // --- MANUÁL ---
  static String get welcomeTitle => isInformal ? "Čus muzikante!" : "Vítejte v Posouvači textů";
  static String get welcomeContent => isInformal 
      ? "Tenhle nástroj ti pohlídá texty i akordy, abys mohl v klidu válet. Všechno je nachystaný i pro čtečky obrazovky."
      : "Tato aplikace vám pomůže s texty a akordy při hraní. Je navržena tak, aby byla plně přístupná pro čtečky obrazovky.";
  
  static String get libraryTitle => isInformal ? "Knihovna a tvý songy" : "Knihovna a import";
  static String get libraryContent => isInformal 
      ? "Tady máš všechen svůj repertoár. Nový fláky v .txt tam hodíš tlačítkem vpravo dole. Když chceš něco upravit, stačí na tom songu podržet prst."
      : "V Knihovně najdete své písně. Nové texty ve formátu .txt importujete tlačítkem vpravo dole. Pokud chcete upravit jméno interpreta nebo název, podržte na písni prst déle.";

  static String get playerTitle => isInformal ? "Přehrávač a jízda" : "Přehrávač a tempo";
  static String get playerContent => isInformal 
      ? "Klepni na text a odstartuješ odpočet i jízdu. Tempo si poladíš tou ikonou tachometru nahoře. Každej song si pamatuje svý."
      : "Klepnutím na text v přehrávači spustíte hlasový odpočet a automatický posuv. Tempo BPM nastavíte ikonou tachometru v horní liště. Nastavení se uloží pro každou píseň zvlášť.";

  static String get extraTitle => isInformal ? "Ladička a setlisty" : "Ladička a Playlisty";
  static String get extraContent => isInformal 
      ? "Naladíš se přes tu notu v knihovně. A přes plusko si songy naházíš do playlistů, třeba na dnešní oslavu."
      : "Ikona noty v Knihovně otevře ladičku. Ikona plus u písně vám umožní zařadit ji do vlastních seznamů, jako jsou například playlisty Olympic nebo Oslava.";

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

  static String get playedButton => isInformal ? "ODEHRÁNO" : "ODEHRÁNO";
  static String get encoreButton => isInformal ? "PŘÍDAVEK!" : "PŘÍDAVEK";

  // --- NASTAVENÍ ---
  static String get themeLight => isInformal ? "Budiž světlo." : "Světlý motiv nastaven.";
  static String get themeDark => isInformal ? "Tma je tu." : "Tmavý motiv nastaven.";
  static String get themeSystem => isInformal ? "Systém rozhodne za nás." : "Systémový motiv nastaven.";
}
