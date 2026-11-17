# Lettura guidata e audio · novembre 2026

Growing readers mostra al massimo due paragrafi per sezione, mantenendo ordine e contenuto delle storie. Il paragrafo attivo ha un bordo azzurro. Il microfono confronta la trascrizione inglese con le parole nell’ordine scritto; maiuscole e punteggiatura non cambiano il risultato. Le parole corrette ricevono uno sfondo azzurro e una sottolineatura. Una parola mancante, diversa o aggiunta impedisce il completamento. Le revisioni dei risultati parziali possono ritirare un’evidenziazione provvisoria.

Dopo una pausa o un nuovo tentativo si riparte dalla prima parola non evidenziata. Quando l’intero paragrafo è riconosciuto, compare la conferma e dopo 1,1 secondi si passa al successivo, alla sezione seguente o alle domande. Il microfono si ferma al completamento del paragrafo: nel successivo si riattiva con un tocco. Il menu More conserva la lettura verificata da un adulto, registrata separatamente e senza modificare il livello automatico.

Sezione, paragrafo e parole lette sono salvati localmente. I salvataggi precedenti continuano a essere decodificati; gli indici delle vecchie sezioni sono ricondotti alle sezioni divise in gruppi da due. La barra di ripresa in home comprende anche il progresso nel paragrafo. Il testo resta stabile durante la lettura; i risultati possono preparare il livello dell’attività successiva.

Hearing sounds riproduce automaticamente l’anteprima all’apertura e a ogni nuova parola, lasciando il tocco per risentirla. Un avvio del microfono interrompe l’anteprima. First words mantiene la lettura con il solo microfono.

## Musica ed effetti

Gli otto MP3 forniti sono inclusi in `ReadLab/ReadLab/Sounds` e copiati nel bundle dell’app:

| Contesto | File |
| --- | --- |
| Onboarding, in loop | Onboard music.mp3 |
| Home, in loop | Home music.mp3 |
| Card Hearing sounds / mascotte | Elephant 1.mp3 / Elephant 2.mp3 |
| Card First words / mascotte | Parrot 1.mp3 / Parrot 2.mp3 |
| Card Growing readers / mascotte | Monkey 1.mp3 / Monkey 2.mp3 |

La musica dell’onboarding sfuma in uscita per 1,2 secondi; solo dopo inizia la musica della home, con ingresso di 0,8 secondi. La musica ha volume relativo 0,20 e gli effetti 0,80, senza modificare il volume di sistema. Si sospendono musica ed effetti all’ingresso negli esercizi o quando l’app diventa inattiva, lasciando la sessione audio alla voce e al microfono. Gli avvii musicali in attesa vengono annullati quando cambia il contesto.

La categoria Ambient rispetta la modalità silenziosa. Le interruzioni di sistema e lo scollegamento delle cuffie sospendono l’audio; il microfono non si riattiva automaticamente. Il pulsante audio permette di fermare o riprendere la musica. In Account, Sound offre interruttori separati per musica e versi, conservati nello stesso dominio delle altre preferenze. Le preview non riproducono audio.

Practice overview si trova in Performance report, accanto all’esportazione PDF. Reading familiarity è rimossa dalla lista Account; il campo storico resta decodificabile nei profili già salvati.

## Verifica

I test del modello coprono parole mancanti, sostituite, aggiunte e ripetute, ripresa dopo una trascrizione parziale, revisione del riconoscimento, avanzamento solo dopo il completamento, accesso alle domande, migrazione e salvataggio del progresso, limite di due paragrafi, conservazione della punteggiatura nell’evidenziazione e decodifica di tutti gli MP3. I test audio controllano scene, preferenze, interruzioni, cuffie, passaggio effettivo tra le musiche e annullamento di una transizione in background.

Il test UI attraversa onboarding e tre percorsi, tocca card e mascotte, controlla le preferenze audio, riprende il secondo paragrafo dopo la chiusura e arriva automaticamente alle domande tramite la conferma di un adulto. Copre anche orientamento verticale e testo di accessibilità. Il microfono reale e la qualità del riconoscimento della voce di un bambino richiedono una prova su iPad con riconoscimento inglese sul dispositivo: il simulatore verifica la logica e la navigazione, non la precisione fonetica.

Verifica completata con Xcode 27.2 su iPad Air 13-inch (M4), iPadOS 27.2: **20 test del modello/audio e 1 test UI completo superati**. Il test finale del modello/audio è in `/tmp/ReadLabAudioFinalUnitTests.xcresult`; il percorso UI completo è in `/tmp/ReadLabAudioTests3.xcresult`. Le schermate esaminate sono in `/tmp/ReadLabAudioScreens3/named`.
