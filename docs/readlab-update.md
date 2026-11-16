# Aggiornamento ReadLab · novembre 2026

## Riferimenti esaminati

Lo ZIP fornito contiene 13 SVG, `Guideline schermata orizzontale.png` e `Settings icon INFO.pdf`. È stato estratto in `/tmp/readlab-references/Schermate per codex`. Gli SVG sono stati visualizzati anche ruotati in orizzontale. Il riferimento Growing readers è stato alleggerito per visualizzarlo con Quick Look, conservando composizione e contenuto.

I riferimenti Onboarding 2 e 3 sono uguali; 3.1 mostra l’opzione OpenDyslexic. Il flusso mantiene i dati del profilo già presenti nell’app e incorpora lo specialista nelle preferenze: cinque passaggi, con scelta di un solo percorso iniziale e riepilogo completo. Le righe di esempio con lingue nel riferimento 5 sono sostituite dai dati effettivamente raccolti; non è stato introdotto un selettore di lingue senza contenuti tradotti.

Il logo, le tre mascotte e le sei immagini delle collezioni provengono dai file forniti. Le mascotte sono estratte come vettori; le due fotografie più grandi sono ridimensionate a 1600 px. Le immagini Animals e Space sono già piccole negli SVG originali: un ingrandimento ne rende visibile la risoluzione limitata. Le storie e gli esercizi sono contenuti locali di prova, non testi integrali dei libri citati nel prompt. OpenDyslexic Bold proviene dal [repository ufficiale](https://github.com/antijingoist/opendyslexic), con licenza inclusa.

## Struttura

`ContentView` decide tra onboarding e home. `ReadLabStore` conserva un modello Codable in UserDefaults; ogni percorso ha sessione e difficoltà indipendenti. La vecchia schermata finale segnaposto è rimossa, i modelli prima sparsi nelle singole viste sono raccolti in `ReadLabModel.swift`, e le sezioni duplicate dello sfondo sono sostituite da componenti condivisi.

Lo shuffle cambia il suggerimento, senza modificare la sessione salvata. Avviare un tema diverso sostituisce la sessione corrente di quel percorso. La card di ripresa usa dati reali e scompare come ripresa quando l’attività è completata. La home suggerisce allora la seconda collezione.

Per le attività vocali, una risposta viene accettata quando la trascrizione contiene esattamente il testo proposto, ignorando maiuscole e punteggiatura. Una trascrizione parziale esatta può completare subito il passo; una trascrizione finale differente conta un tentativo. Silenzio, permessi negati ed errori del servizio non abbassano la difficoltà. Un adulto può confermare una lettura senza influenzare il livello automatico. Il passaggio automatico avviene dopo 2,5 secondi e si può anticipare con il pulsante successivo.

La difficoltà proposta resta stabile durante una storia, anche se le risposte corrette preparano il livello successivo. Due errori che abbassano il livello ripropongono la storia in versione più semplice. Nella lettura di parole, il livello può cambiare già alla parola successiva. Si riparte da contenuti semplici, senza derivare capacità dal nome, dall’età o dalle differenze di apprendimento dichiarate.

## Design e accessibilità

Palette dei riferimenti: Sky `#BFD5E1`, Sand `#F9DCB2`, Coral `#FF9297`. Titoli arrotondati di sistema, descrizioni di sistema e OpenDyslexic Bold solo su scelta dell’utente. Le forme dello sfondo ruotano e cambiano leggermente curvatura; Riduci movimento disattiva questi effetti e le animazioni di crescita. Le scelte hanno anche un segno di spunta. Controlli di lettura e dimensione del testo restano nell’attività; le preferenze generali sono in un foglio Account nativo, secondo il PDF fornito.

Sono stati consultati i riferimenti HIG della skill apple-design: `layout.md` (Adaptability), `typography.md` (Ensuring legibility), `accessibility.md`, `color.md`, `designing-for-ios.md`, `motion.md` (Best practices), `settings.md` (General settings / Task-specific options), `popovers.md` e `privacy.md` (Requesting permission). Il pulsante principale usa testo scuro sul celeste per una maggiore leggibilità. Le viste seguono lo spazio disponibile, con scroll, Dynamic Type e cursori etichettati per VoiceOver.

## Verifiche

Build per iPad Simulator riuscita con Xcode 27.2. Nove test del modello verificano soglie e limiti della difficoltà, interruzione delle sequenze di successi, confronto vocale, ripresa separata dopo riavvio, rinuncia ai conteggi, completamento idempotente, 2–6 sillabe, struttura crescente delle storie e registrazione del font.

Il test UI attraversa tutti i cinque passaggi, attiva il font, avvia le tre attività, regola i cursori, cambia percorso da Account, riavvia l’app, riprende le sessioni e completa una storia. Verifica anche la navigazione in verticale, il percorso con un adulto, la riapertura con Dynamic Type al massimo livello di accessibilità e la raggiungibilità del microfono. I risultati e le schermate sono nelle cartelle temporanee `/tmp/ReadLabFinalTests.xcresult` e `/tmp/ReadLabFinalScreens/named`. Il test finale è passato con 9 test del modello e 1 test UI completo.

Il simulatore non convalida la qualità del riconoscimento della voce di un bambino. Rimane necessaria una prova su iPad fisico con il modello inglese di riconoscimento sul dispositivo disponibile. L’adattamento è una regola di pratica, non una valutazione diagnostica o fonetica.
