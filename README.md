# ReadLab

App SwiftUI esclusivamente per iPad: un percorso di lettura in inglese che parte da suoni e parole e arriva alla comprensione di storie. L’interfaccia usa la modalità a schermo intero e rimane in orizzontale anche ruotando il dispositivo in verticale; sono supportati entrambi i versi orizzontali. Il progetto non include un target iPhone.

Aprire `ReadLab/ReadLab.xcodeproj` in Xcode. Il progetto usa il formato `project.xcproj` di Xcode 27.2 e mantiene il deployment target originale iOS/iPadOS 27.2.

Per vedere e navigare tutta l’app nel Canvas, aprire **ContentView.swift** e avviare la preview interattiva “Complete app”. Le preview usano dati separati da quelli dell’app. È disponibile anche una preview della home First words.

- Onboarding in cinque passaggi: benvenuto, profilo, preferenze e supporto, percorso, riepilogo modificabile.
- Hearing sounds: ascolto automatico di ogni nuova parola, ripetibile al tocco, lettura ad alta voce e albero che cresce quando vengono riconosciute le parole proposte.
- First words: parole e brevi frasi da 2 a 6 sillabe, cursore di focus sulle sillabe e dimensione del testo regolabile.
- Growing readers: due storie originali/adattate in cinque livelli, sezioni di massimo due paragrafi, microfono con evidenziazione delle parole riconosciute e avanzamento automatico al paragrafo successivo o alle domande di comprensione.
- Account: cambio del percorso, OpenDyslexic Bold, profilo, supporto, controlli audio e Practice overview nella sezione Performance report.
- Salvataggio locale per argomento, libro e livello. La barra nella home mostra le parole o le pagine completate. Toccando il riquadro si riparte dal punto salvato.

La difficoltà iniziale è Easy per 4–5 anni, Medium per 6–7 e 8–9 anni e Hard per 10+. In First Words e Hearing Sounds ogni argomento sblocca il livello successivo dopo sei parole. La home mostra il progresso del nuovo livello e il completamento del precedente. Due errori consecutivi o due cambi di attività dopo un errore possono proporre un livello più facile. In Growing Readers le prestazioni determinano l’edizione dei libri aperti per la prima volta. La lettura con un adulto fa avanzare l’attività. Disattivare il riepilogo della pratica cancella i conteggi del report, mentre il salvataggio della posizione e dei livelli resta disponibile.

Il pulsante circolare con il microfono avvia e conclude l’ascolto. In Hearing sounds la parola viene letta automaticamente e si può toccare per risentirla; anche i paragrafi di Growing readers hanno un’anteprima al tocco. In First words si legge con il microfono, senza anteprima o salto della parola. Il permesso del microfono viene richiesto solo al tocco del microfono. Il riconoscimento usa Speech di Apple esclusivamente sul dispositivo, quando disponibile per l’inglese; l’app non conserva registrazioni. Se non è disponibile, resta possibile ascoltare e praticare con un adulto. Il confronto verifica le **parole trascritte**, non misura la precisione fonetica della pronuncia. La voce reale va verificata su iPad fisico.

L’onboarding riproduce in loop **Onboard music.mp3**; alla conclusione sfuma in uscita per 1,2 secondi prima dell’ingresso di **Home music.mp3**. La musica si sospende negli esercizi e quando l’app non è attiva. Il pulsante audio e le preferenze Account permettono di disattivarla; i versi degli animali hanno una preferenza separata. Le card usano i file “1”, le mascotte i file “2” di Elephant, Parrot e Monkey. Tutti gli otto MP3 forniti sono inclusi nell’app.

Le verifiche di lettura e audio sono descritte in [docs/readlab-audio-and-reading.md](docs/readlab-audio-and-reading.md).

I riferimenti, le scelte e le verifiche sono descritti in [docs/readlab-update.md](docs/readlab-update.md). OpenDyslexic Bold è incluso con [licenza SIL OFL](ReadLab/ReadLab/Fonts/OFL.txt).

Per compilare e testare, con Xcode selezionato:

```sh
xcodebuild -project ReadLab/ReadLab.xcodeproj \
  -scheme ReadLab -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO test
```

La revisione delle proporzioni è descritta in [docs/readlab-design-revision.md](docs/readlab-design-revision.md).

I test UI usano un dominio UserDefaults dedicato e non cancellano il profilo dell’app normale.
