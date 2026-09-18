# Galoppal Universal-/App-Link-Setup für galoppal.de

Trainer-Einladungslinks sehen jetzt so aus:

    https://galoppal.de/t/vogt-3f9a

Ist die App installiert und die Domain vom Betriebssystem verifiziert, öffnet
ein Tap auf diesen Link die App **direkt** bei diesem Reitlehrer — kein
Umweg über den Browser. Ist die App nicht installiert (oder die Verifizierung
noch nicht durchgelaufen), landet man auf der Fallback-Seite in diesem
Ordner (`t/index.html`) mit Store-Buttons und einer kleinen Vorschau, wer
eingeladen hat.

## Was du noch ausfüllen musst

1. **`​.well-known/apple-app-site-association`** — `REPLACE_WITH_TEAM_ID`
   durch deine 10-stellige **Apple Team ID** ersetzen (Apple Developer
   Portal → *Membership* → *Team ID*). Das Ergebnis sieht z. B. so aus:
   `"appID": "ABCDE12345.de.trainalign.trainalign"`.

2. **`.well-known/assetlinks.json`** — `REPLACE_WITH_YOUR_SHA256_FINGERPRINT`
   durch den **SHA-256-Fingerabdruck deines Android-Signing-Zertifikats**
   ersetzen. Du bekommst ihn über:
   - Play Console → dein App → *Setup* → *App-Integrität* → *App-Signaturschlüssel-Zertifikat*, oder
   - lokal: `keytool -list -v -keystore <dein-release.keystore> -alias <alias>`

   Mehrere Fingerabdrücke (z. B. Debug- und Release-Build) sind als Array
   möglich:
   ```json
   "sha256_cert_fingerprints": ["AA:BB:...", "CC:DD:..."]
   ```

3. **`t/index.html`** — im `<script>`-Block `SUPABASE_URL` und
   `SUPABASE_ANON_KEY` eintragen (dieselben Werte wie in der `.env` der App,
   zu finden unter Supabase-Dashboard → *Project Settings → API*). Der
   Anon-Key ist bewusst öffentlich nutzbar — Zeilen wie diese sehen dank der
   Datenbank-Regel `profiles_select_public_trainers` (siehe
   `supabase/schema.sql`) ausschließlich Trainer-Profile, nichts Privates.

   Außerdem die beiden Store-Links eintragen, sobald die App veröffentlicht
   ist (`store-btn`-Links in derselben Datei).

## Wo die Dateien hin müssen

Beide Domain-Verifizierungsdateien müssen **exakt** unter diesen Pfaden
erreichbar sein, ohne Redirect, mit `Content-Type: application/json`:

```
https://galoppal.de/.well-known/apple-app-site-association
https://galoppal.de/.well-known/assetlinks.json
```

Die Fallback-Seite muss unter jedem `/t/<code>` erscheinen — also ein
**Rewrite** (nicht Redirect) von `/t/*` auf `t/index.html`, damit die URL im
Browser unverändert bleibt (die Seite liest den Code selbst aus dem Pfad).

### Vercel
`vercel.json` im Projekt-Root:
```json
{
  "rewrites": [
    { "source": "/t/:code", "destination": "/t/index.html" }
  ]
}
```
`apple-app-site-association` braucht keinen expliziten Content-Type-Eintrag —
Vercel liefert `.well-known`-Dateien ohne Erweiterung standardmäßig korrekt aus.
Falls doch nötig, in `vercel.json` ergänzen:
```json
{
  "headers": [
    {
      "source": "/.well-known/apple-app-site-association",
      "headers": [{ "key": "Content-Type", "value": "application/json" }]
    }
  ]
}
```

### Netlify / Cloudflare Pages
Datei `_redirects` im Publish-Verzeichnis:
```
/t/*  /t/index.html  200
```
Für den Content-Type der AASA-Datei bei Bedarf eine `_headers`-Datei:
```
/.well-known/apple-app-site-association
  Content-Type: application/json
```

### Eigener Server (nginx)
```nginx
location = /.well-known/apple-app-site-association {
    default_type application/json;
}
location = /.well-known/assetlinks.json {
    default_type application/json;
}
location /t/ {
    try_files $uri /t/index.html;
}
```

## Nach dem Hochladen prüfen

- `curl -I https://galoppal.de/.well-known/apple-app-site-association`
  → Status 200, `Content-Type: application/json`, **kein** Redirect.
- Apple's Validator: https://search.developer.apple.com/appsearch-validation-tool/
  (Domain eingeben, prüft die AASA-Datei automatisch).
- Android: `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://galoppal.de&relation=delegate_permission/common.handle_all_urls`
  sollte dein `assetlinks.json` zurückgeben.

Beide Betriebssysteme cachen die Verifizierung — nach Änderungen kann es ein
paar Stunden dauern (iOS meist schneller, Android teils erst nach App-Neuinstallation).

## Was in der App schon vorbereitet ist

- iOS: `ios/Runner/Runner.entitlements` deklariert
  `applinks:galoppal.de` (Associated Domains), in allen drei Build-Configs
  des `Runner`-Targets verdrahtet.
- Android: `AndroidManifest.xml` hat einen `autoVerify`-Intent-Filter für
  `https://galoppal.de/t/*`.
- Die App hört in `lib/main.dart` (Paket `app_links`) auf eingehende Links,
  extrahiert den Code hinter `/t/` und übergibt ihn an
  `AppState.handleIncomingInviteCode` — meldet sich der Nutzer gerade nicht
  an oder ist gerade als Trainer statt Schüler unterwegs, wird der Code
  gemerkt und beim nächsten passenden Moment automatisch eingelöst.
- Bundle-Identifier/Package-Name bleiben unverändert:
  `de.trainalign.trainalign` (iOS und Android).
