# ReadLab

App SwiftUI per iPad: un percorso di lettura in inglese che parte da suoni e parole e arriva alla comprensione di storie. Layout principale in orizzontale, con disposizione adattiva in verticale.

Aprire `ReaddingSuport/ReaddingSuport.xcodeproj` in Xcode. Il progetto usa il formato `project.xcproj` di Xcode 27.2 e mantiene il deployment target originale iOS/iPadOS 27.2.

Per vedere e navigare tutta l’app nel Canvas, aprire **ContentView.swift** e avviare la preview interattiva “Complete app”. Le preview usano dati separati da quelli dell’app. È disponibile anche una preview della home First words.

- Onboarding in cinque passaggi: benvenuto, profilo, preferenze e supporto, percorso, riepilogo modificabile.
- Hearing sounds: ascolto, lettura ad alta voce e albero che cresce quando vengono riconosciute le parole proposte.
- First words: parole e brevi frasi da 2 a 6 sillabe, cursore di focus sulle sillabe e dimensione del testo regolabile.
- Growing readers: due storie originali/adattate in cinque livelli, sezioni di massimo tre paragrafi e domande di comprensione.
- Account: cambio del percorso, OpenDyslexic Bold, profilo, supporto e riepilogo della pratica.
- Salvataggio locale separato per ciascun percorso: tema, parola, sezione e domanda. La X e la chiusura dell’app conservano la posizione.

La difficoltà cambia con regole locali: tre risposte corrette consecutive aumentano il livello, due errori lo riducono, entro cinque livelli. Non serve Apple Intelligence. Le attività con un adulto e le parole saltate non influenzano il livello automatico. Disattivare il riepilogo della pratica cancella i conteggi; posizione e adattamento continuano a funzionare.

Il microfono viene richiesto solo premendo “Read Aloud”. Il riconoscimento usa Speech di Apple esclusivamente sul dispositivo, quando disponibile per l’inglese; l’app non conserva registrazioni. Se non è disponibile, resta possibile ascoltare e praticare con un adulto. Il confronto verifica le **parole trascritte**, non misura la precisione fonetica della pronuncia. La voce reale va verificata su iPad fisico.

I riferimenti, le scelte e le verifiche sono descritti in [docs/readlab-update.md](docs/readlab-update.md). OpenDyslexic Bold è incluso con [licenza SIL OFL](ReaddingSuport/ReaddingSuport/Fonts/OFL.txt).

Per compilare e testare, con Xcode selezionato:

```sh
xcodebuild -project ReaddingSuport/ReaddingSuport.xcodeproj \
  -scheme ReaddingSuport -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO test
```

I test UI usano un dominio UserDefaults dedicato e non cancellano il profilo dell’app normale.
