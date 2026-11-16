# Revisione dei riferimenti e rinomina ReadLab

Il progetto è ora `ReadLab/ReadLab.xcodeproj`, con target `ReadLab`, `ReadLabTests` e `ReadLabUITests`. La radice SwiftUI è `ReadLabApp.swift` e l’onboarding è in `ReadLabOnboarding.swift`. Nomi del prodotto, modulo, bundle ID, collegamenti dei test, configurazione del workspace VS Code e documentazione seguono il nuovo nome. Il bundle ID di sviluppo ora termina in `.ReadLab`; iOS lo considera un’installazione distinta dalla build con il precedente identificatore.

Le misure sono state ricontrollate negli attributi SVG originali e nella guida orizzontale, sulla tavola di riferimento da 1366 × 1024 pt:

| Elemento | Misura |
| --- | --- |
| Nome del percorso nella home e domanda principale | 70 pt, Rounded Medium |
| Titolo della collezione | 35 pt, Rounded Semibold |
| Descrizione della collezione | 25 pt |
| Card principale in orizzontale | 655 × 600 pt, con immagine alta 309 pt |
| Spazio fra le colonne della home | 50 pt |
| Card laterale | 534 × 105 pt |
| Headline della scelta del percorso | 70 pt |
| Introduzione alla scelta del percorso | 25 pt |
| Corpo delle tre card focus | 278 × 332 pt |
| Titoli interni alle card focus | 26 pt su due righe |
| Descrizioni interne alle card focus | 15 pt, come riportato negli SVG |
| Mascotte delle card focus | sopra il bordo, con sovrapposizione di 24 pt |

La disposizione delle home segue la guida orizzontale; le altre proporzioni riprendono gli SVG ruotati. Su finestre più piccole o con testo di accessibilità i contenuti si dispongono verticalmente e restano scorrevoli. Le misure non vengono imposte tagliando il testo grande. Le diciture di ripresa e gli indicatori continuano a dipendere dai dati effettivi della sessione.

Il microfono è un pulsante circolare da 96 pt, con gradiente grigio e simbolo bianco vettoriale ricostruito dal riferimento allegato. Un secondo tocco termina l’ingresso audio e attende il riconoscimento. Durante preparazione e riconoscimento compare un indicatore; la registrazione è segnalata da un anello celeste che reagisce al volume. Il controllo mantiene nome, stato e suggerimento per VoiceOver. L’ascolto del modello audio avviene toccando la parola, l’insieme delle sillabe oppure il paragrafo. Avviare una lettura di esempio interrompe il microfono per evitare che la voce di esempio venga conteggiata come risposta.

Lo sfondo usa un contorno chiuso a 12 punti con tangenti continue. Le onde percorrono il bordo in 8 secondi e la rotazione oscilla di 18° in 14 secondi; le tre figure hanno fasi diverse. TimelineView aggiorna a 30 fps e sospende l’aggiornamento quando la scena non è attiva. Riduci movimento mostra una forma statica.

La scelta dei controlli rispetta i riferimenti HIG consultati: `buttons.md › Best practices` per area di tocco e stato di pressione, `motion.md › Best practices` per Riduci movimento, `layout.md › Adaptability` per finestre ridotte e Dynamic Type.

Verifica: build del nuovo schema ReadLab riuscita e 9 test del modello più 1 test UI completo superati su iPad Air 13″. Le schermate sono in `/tmp/ReadLabRevisionScreens/named`, con font standard per il confronto visivo; il test verifica anche l’attivazione del font alternativo e il testo di accessibilità grande.
