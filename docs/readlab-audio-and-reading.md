# Lettura guidata e audio · novembre 2026

Growing readers mostra al massimo due paragrafi per sezione, mantenendo ordine e contenuto delle storie. Il paragrafo attivo ha un bordo azzurro. Il microfono confronta la trascrizione inglese con le parole nell’ordine scritto; maiuscole e punteggiatura non cambiano il risultato. Le parole corrette ricevono uno sfondo azzurro e una sottolineatura. Il cursore aspetta la prossima parola prevista e confronta le possibili pronunce di CMUdict, per esempio “sea” per “see” o “heels” per “hills”. Può anche usare le trascrizioni alternative fornite da Speech per la stessa posizione nell’audio. La trascrizione di Speech viene usata internamente e non viene mostrata durante l’ascolto. Una parola saltata resta da leggere. I risultati parziali possono far avanzare l’evidenziazione, che non torna indietro quando la trascrizione viene rivista.

Hearing sounds, First words e Growing readers usano Speech di Apple sul dispositivo. Durante l’ascolto viene mostrato solo lo stato “I’m listening…”, senza anteprima delle parole trascritte. In Growing Reader proseguono l’evidenziazione del testo originale e il conteggio delle parole accettate. Il microfono resta attivo al passaggio tra paragrafi e sezioni e si ferma quando iniziano le domande. Dopo uno stop o un nuovo tentativo si riparte dalla prima parola non evidenziata. Il menu More conserva la lettura verificata da un adulto, registrata separatamente e senza modificare il livello automatico.

Sezione, paragrafo e parole lette sono salvati localmente. I salvataggi precedenti continuano a essere decodificati; gli indici delle vecchie sezioni sono ricondotti alle sezioni divise in gruppi da due. La barra di ripresa in home comprende anche il progresso nel paragrafo. Il testo resta stabile durante la lettura; i risultati possono preparare il livello dell’attività successiva.

Hearing sounds riproduce automaticamente l’anteprima all’apertura e a ogni nuova parola, lasciando il tocco per risentirla. Un avvio del microfono interrompe l’anteprima. First words mantiene la lettura con il solo microfono.

## Dizionario di pronuncia

ReadLab include [CMUdict](https://github.com/cmusphinx/cmudict) di Carnegie Mellon University, alla [revisione `7479086`](https://github.com/cmusphinx/cmudict/tree/74790861f652b15e4ac49015a90074ad62a27690). Il dizionario originale (`cmudict.dict` a monte, `cmudict.txt` nel bundle per il formato di risorsa Xcode) e la [licenza](../ReadLab/ReadLab/Pronunciation/CMUdict-LICENSE.txt) sono distribuiti nel bundle dell’app. La ricerca avviene in locale, senza richieste di rete.

`PhoneticMatcher` verifica tutte le pronunce disponibili e conserva l’accento lessicale indicato nel dizionario. Una sequenza CMU identica è sempre accettata, senza elenchi manuali di omofoni. La normalizzazione di Growing Reader conserva contrazioni e possessivi come parole intere e uniforma gli apostrofi tipografici: `its` e `it’s`, per esempio, si confrontano tramite il dizionario. Contatore ed evidenziazione condividono gli stessi confini delle parole; il testo originale resta invariato.

La configurazione `.growingReader` ammette solo le confusioni direzionali richieste: hills → heels, walking → working, reach → rich, slip → sleep, branch → brunch, branches → brunches, ball → bowl, sitting → setting, warm → worm, chirp → chip, chirps → chips/chip, chirping → chipping, twigs → tweaks/tweets, fall → fault, walks → walk/works e picks → pics/pizza. Il cursore accetta anche `pick up` quando il testo attende `picks up`, verificando entrambe le parole. Non sono attive sostituzioni generali tra vocali né omissioni generali di consonanti finali. Le alternative allineate di Speech passano dallo stesso confronto. Le revisioni di una parola già accettata non la conteggiano di nuovo. Le parole assenti dal dizionario restano confrontabili per grafia esatta. Hearing sounds e First words conservano il confronto esatto e la normalizzazione precedenti.

## Animali nelle storie

Growing Reader riproduce i versi toccando direttamente gli animali illustrati; il pulsante della scimmia nella barra superiore è rimosso. Le aree interattive seguono posizione e dimensioni degli animali in tutte le 27 illustrazioni, sia con immagine adattata in verticale sia con ritaglio in orizzontale. Si usano gli MP3 già inclusi: Monkey 2, Elephant 2 e Parrot 2 per l’uccellino.

Durante il verso tutti gli animali sono temporaneamente disabilitati e quello selezionato mostra un indicatore di pausa. Il blocco termina 750 ms dopo la fine del suono, poi l’ascolto riprende dalla posizione salvata. I tocchi durante questa pausa vengono ignorati. La preferenza Animal sounds continua a controllare questi effetti; i controlli hanno etichette accessibili e aree di almeno 44 punti. Le anteprime in home e gli altri percorsi restano invariati.

CMUdict descrive l’inglese americano. Può mancare di nomi, varianti regionali o pronunce individuali. Il confronto valuta le pronunce possibili delle parole trascritte e non può verificare i fonemi realmente pronunciati dal bambino. “Cool” e “call” non sono equivalenti a “could” nel dizionario. L’app può accettare “could” se Speech lo propone come alternativa per la stessa parola.

## Musica ed effetti

Gli otto MP3 forniti sono inclusi in `ReadLab/ReadLab/Sounds` e copiati nel bundle dell’app:

| Contesto | File |
| --- | --- |
| Onboarding, in loop | Onboard music.mp3 |
| Home, in loop | Home music.mp3 |
| Card Hearing sounds / mascotte | Elephant 1.mp3 / Elephant 2.mp3 |
| Card First words / mascotte | Parrot 1.mp3 / Parrot 2.mp3 |
| Card Growing readers / mascotte | Monkey 1.mp3 / Monkey 2.mp3 |

La musica dell’onboarding sfuma in uscita per 1,2 secondi; solo dopo inizia la musica della home, con ingresso di 0,8 secondi. I volumi sono configurabili in `ReadLabSound.volumePercent`: musica al 20%, effetti all’80% e Monkey 1 al 15%. Il volume di sistema resta indipendente. Si sospendono musica ed effetti all’ingresso negli esercizi o quando l’app diventa inattiva, lasciando la sessione audio alla voce e al microfono. Gli avvii musicali in attesa vengono annullati quando cambia il contesto.

La categoria Ambient rispetta la modalità silenziosa. Le interruzioni di sistema e lo scollegamento delle cuffie sospendono l’audio; il microfono non si riattiva automaticamente. Il pulsante audio permette di fermare o riprendere la musica. In Account, Sound offre interruttori separati per musica e versi, conservati nello stesso dominio delle altre preferenze. Le preview non riproducono audio.

Practice overview si trova in Performance report, accanto all’esportazione PDF. Reading familiarity è rimossa dalla lista Account; il campo storico resta decodificabile nei profili già salvati.

## Verifica

I test del modello coprono parole mancanti e ripetute, esitazioni, ripresa tra segmenti e revisioni di una trascrizione parziale, avanzamento solo dopo il completamento, accesso alle domande, migrazione e salvataggio del progresso, limite di due paragrafi, conservazione della punteggiatura nell’evidenziazione e decodifica di tutti gli MP3. I test audio controllano scene, preferenze, interruzioni, cuffie, passaggio effettivo tra le musiche e annullamento di una transizione in background.

Il test UI attraversa onboarding e tre percorsi, tocca card e mascotte, controlla le preferenze audio, riprende il secondo paragrafo dopo la chiusura e arriva automaticamente alle domande tramite la conferma di un adulto. Copre anche orientamento verticale e testo di accessibilità. Il microfono reale e la qualità del riconoscimento della voce di un bambino richiedono una prova su iPad con riconoscimento inglese sul dispositivo: il simulatore verifica la logica e la navigazione, non la precisione fonetica.

Verifica completata con Xcode 27.2 su iPad Air 13-inch (M4), iPadOS 27.2: **20 test del modello/audio e 1 test UI completo superati**. Il test finale del modello/audio è in `/tmp/ReadLabAudioFinalUnitTests.xcresult`; il percorso UI completo è in `/tmp/ReadLabAudioTests3.xcresult`. Le schermate esaminate sono in `/tmp/ReadLabAudioScreens3/named`.

Revisione del 24 novembre 2026, sullo stesso modello di simulatore: **37 test del modello/audio e 1 test UI completo superati, senza fallimenti**. Sono coperti omofoni CMU e pronunce multiple, apostrofi, tutte le confusioni mirate con controesempi, le pagine originali di Monkey’s Adventure con walks/walk/works, pick up nel solo contesto picks up, revisioni senza doppio conteggio e geometria delle aree animali nelle 27 pagine. Il test UI verifica i tre percorsi, i versi di scimmia/elefante/uccellino, il blocco degli altri animali durante la pausa, ripresa, orientamenti e testo di accessibilità. Risultati: `/tmp/ReadLabGrowingReaderFinalUnitTests.xcresult` e `/tmp/ReadLabGrowingReaderUITests.xcresult`; schermate in `/tmp/ReadLabGrowingReaderScreens`.
