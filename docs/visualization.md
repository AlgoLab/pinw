## Dizionario top-level:  
      
    key="sequence_id"; value -> FASTA header del file della genomica (senza '>')  
    key="program_version"; value -> versione della pipeline che ha prodotto il JSON  
    key="file_format_version"; value -> versione dello schema JSON  
    key="regions"; value -> array delle regioni              
    key="boundaries"; value -> array dei boundaries  
    key="exons"; value -> array degli esoni  
    key="introns"; value -> array degli introni  
    key="isoforms"; value -> array delle isoforme  
 
*********************************************************************************************************************************  
## Regione 
E’ una regione massimale che verifica una delle seguenti condizioni:  
1. è inclusa totalmente in tutte le isoforme -->> regione codificante conservata  
2. è inclusa totalmente in almeno un'isoforma ma non in tutte -->> regione codificante alternativa  
3. è esclusa da tutte le isoforme -->> regione non codificante (sempre intronica quindi)  
4. regione unknown (non si sa cosa rappresenti)  
      
Le regioni (ordinate) sulla genomica sono fornite dalla chiave "regions"  
* key="regions"; value -> array delle regioni


   Ogni regione è un dizionario con le seguenti chiavi:  
* key="start"; value -> posizione 1-based di inizio sulla genomica  
* key="end"; value -> posizione 1-based di fine sulla genomica  
* key="sequence"; value -> sequenza nucleotidica  **dove va presa?**
* key="type"; value -> "coding" se la regione è codificante in almeno una isoforma, “intron” se non è codificante per nessuna isoforma, "spliced" se è codificante per almeno una ma non tutte le isoforme, "unknown" se è unknown  
* key="alternative?"; value -> true se la regione codificante e' alternativa, false se e' conservata (chiave obbligatoria solo se "type"="coding"; non ha senso per "type" diverso da "coding")  
* key="coverage"; value -> valore di copertura  **dove va presa?**
* key="last?"; value -> true se e' l'ultima regione nell'array "regions", altrimenti false  
* key="id"; value -> indice di posizione della regione all'interno dell'array "regions"  
* key="intron number"; value -> number of introns including the region
* key="exon number"; value -> number of exons including the region
                      
   Note
1. nella visualizzazione, l'altezza del rettangolo che rappresenta una regione codificante dovrebbe essere proporzionale al valore di "coverage" (Attenzione: per type="spliced"|"unknown" questo valore non ha senso)  
 
## Boundary
è il confine tra due regioni consecutive sulla genomica. Le due regioni separate da un boundary sono chiamate regione di sinistra e regione di destra
      
I boundaries (ordinati) sulla genomica sono forniti dalla chiave "boundaries"  
* key="boundaries"; value -> array di boundaries  
* Ogni elemento dell'array e' un dizionario con le seguenti chiavi:  
   * key=”lcoordinate”; value coordinata maggiore della regione di sinistra
   * key=”rcoordinate”; value coordinata minima della regione di destra
   * key="first"; value -> posizione della regione di sinistra all'interno dell'array "regions"  
   *  key="type"; value -> "5" se e' un sito 5', cioe' un confine esone-introne, "3" se e' un sito 3', cioe' un confine introne-esone, "both" se e' sia 5' che 3', "init" se e' un inizio di trascrizione, "term" se e' una  
                            fine di trascrizione, e "unknown" in tutti gli altri casi.  
Note
1. se una delle due regioni che definiscono il boundary e' unknown (sicuramente non entrambe), il boundary non e' sicuramente uno splice site  
2. "first"=-1 significa che non esiste una regione di sinistra (ovvero e' da trattare come unknown) e la regione di destra ha indice di posizione pari a 0: il boundary non e' sicuramente uno splice site  
3. "last?"=true per la regione di indice "first" (quella di sinistra) significa che non esiste una regione di destra (ovvero e' da trattare come unknown): il boundary non e' sicuramente uno splice site  
4. ("first"+1) fornisce l'indice di posizione (nell'array "regions") della regione di destra, solo nel caso in cui si abbia "first"=-1 OPPURE "last?"=false per la regione (di sinistra) di indice "first"                                      
5. "type"="5" significa che il boundary e' un confine esone-introne: la fine dell'esone coincide con "end" della regione di sinistra, mentre l'inizio dell'introne coincide con "start" della regione di destra
6. "type"="3" significa che il boundary e' un confine introne-esone: la fine dell'introne coincide con "end" della regione di sinistra, mentre l'inizio dell'esone coincide con "start" della regione di destra  
7. type="both" significa che il boundary e' sia un confine esone-introne che introne-esone.
8. type="init" significa che lo "start" della regione di destra e' un inizio di trascrizione  
9. type="term" significa che l'"end" della regione di sinistra e' un terminazione di trascrizione   


### Procedure:
Il primo passo è calcolare tutte le lcoordinate delle varie boundary. Per fare questo si leggono gli introni e gli esoni del json di pintron che compongono ogni isoforma. Tutte le coordinate “relative end” sono lcoordinate (mi basta prendere i valori distinti di “relative end”).
Analogamente le rcoordinate sono tutte le coordinate “relative start” distinte.
Si ordinano lcoordinate e rcoordinate.


Una regione ha come “start” una lcoordinate e per “end” la rcoordinate minima fra tutte quelle maggiori di “start”.


Una scansione degli introni e delle isoforme del json di pintron permette di calcolare per ogni regione, i valori di “intron number” e “exon number”, per ogni boundary il valore di “first”


Per assegnare il valore di “type” di ogni regione, è coding se “exon number” è maggiore di zero, con “alternative?” vero se “exon number” è minore del numero di isoforme  **è il totale delle isoforme presenti nel json?**, è intron se “exon number” è zero ma “intron number” è maggiore di zero; unknown in ogni altro caso.


Gli altri campi mi sembrano immediati da calcolare.
## Esone  
      
    L'insieme degli esoni e' fornito dalla chiave "exons"  
            key="exons"; value -> array di esoni  
            Ogni elemento dell'array e' un dizionario con le seguenti chiavi:  
                    key="left_boundary"; value -> indice di posizione del left boundary L dell'esone all'interno dell'array "boundaries"  
                    key="right_boundary"; value -> indice di posizione del right boundary R dell'esone all'interno dell'array "boundaries"  
                    key="annotated?"; value -> true se annotato, false altrimenti  
                      
                    NOTE:  
                            (1) Il left boundary L deve avere una regione di destra con "type"="coding" (cioe' deve essere  
                                    codificante); il suo "start" coincide con lo start dell'esone  
                            (2) Il right boundary R deve avere una regione di sinistra con "type"="coding" (cioe' deve essere  
                                    codificante); il sup "end" coincide con l'end dell'esone  
                            (3) Se "type" di L e' "unknown" allora l'esone sara' incompleto a sinistra (NB: se non e' "unknown, allora  
                                    puo' essere solo "3", "both", o "init)  
                            (4) Se "type" di R e' "unknown" allora l'esone sara' incompleto a destra (NB: se non e' "unknown, allora  
                                    puo' essere solo "5", "both", o "term)  
                            (5) La sequenza nucleotidica dell'esone e' ottenuta concatenando le sequenze delle regioni di indice s, s+1, ..., e  
                                    dove s coincide con l'indice della regione di destra del left boundary ed e coincide con l'indice della regione  
                                    di sinistra del right boundary; tutte queste regioni non possono avere "type" diverso da "coding"  
                                    (cioe' devono essere tutte codificanti). Se una di queste regioni ha "sequence" nulla, allora  
                                    non e' possibile fornire la sequenza dell'esone.
                                    
**quando vado a calcolare i boundaries degli esoni i confini di alcuni non coincidono con quelli di nessuna regine (la procedura per cui si prendeva il min dei margini superiori esclude qualche confine dall'insieme, così mi trovo degli esoni che non so dove finiscono (ho messo -1 nel json prodotto)**
                      
*********************************************************************************************************************************  
## Introne  
      
    L'insieme degli introni e' fornito dalla chiave "introns"  
            key="introns"; value -> array di introni  
            Ogni elemento dell'array e' un dizionario con le seguenti chiavi:  
                    key="left_boundary"; value -> indice di posizione del left boundary L dell'introne all'interno dell'array "boundaries"  
                    key="right_boundary"; value -> indice di posizione del right boundary R dell'introne all'interno dell'array "boundaries"  
                    key="prefix"; value -> sequenza di un prefisso dell'introne  
                    key="suffix"; value -> sequenza di un suffisso dell'introne  
                      
                    NOTE:  
                            (1) Il left boundary L deve avere una regione di destra con "type"="coding"|"spliced" (cioe' non puo' essere  
                                    unknown; se "type"="coding" allora deve essere "alternative?"=true); il suo "start" coincide con lo start  
                                    dell'introne  
                            (2) Il right boundary R deve avere una regione di sinistra con "type"="coding"|"spliced" (cioe' non puo' essere  
                                    unknown; se "type"="coding" allora deve essere "alternative?"=true); il suo "end" coincide con  
                                    l'end dell'introne  
                            (3) "type" di L puo' essere solo "5" oppure "both"  
                            (4) "type" di R puo' essere solo "3" oppure "both"  
                            (5) La sequenza nucleotidica dell'introne e' ottenuta concatenando le sequenze delle regioni di indice s, s+1, ..., e  
                                    dove s coincide con l'indice della regione di destra del left boundary ed e coincide con l'indice della regione  
                                    di sinistra del right boundary; tutte queste regioni non possono avere "type" uguale a "unknown".  
                                    Le regioni con "type"="coding" (cioe' le regioni codificanti) devono necessariamente avere "alternative?"=true  
                                    (cioe' devono essere alternative). Se una di queste regioni ha "sequence" nulla, allora la sequenza dell'introne non  
                                    e' determinabile.  
                            (6) "prefix"/"suffix" coincidono con un prefisso/suffisso della sequenza determinata secondo (5)  
                            (7) Il pattern dell'introne e' dato dai primi due simboli di "prefix" e dagli ultimi due simboli di "suffix"  
                      
*********************************************************************************************************************************  
## Isoforma  
 
    L'insieme delle isoforme e' fornito dalla chiave "isoforms"  
            key="isoforms"; value -> array di isoforme  
            Ogni elemento dell'array e' a sua volta un array di indici che fanno riferimento alle posizioni nell'array "regions"  
              
            NOTE:  
                    (1) le regioni di un'isoforma devono avere "type"="coding" (cioe' devono essere tutte codificanti)  
                    
**prendo direttamente tutte le isoforme dal json di pintron? non ho ben capito come è strutturato l'elemento dell'array. Oltre alla chiave type le altre chiavi come si chiamano? 'left_boundary' e 'right_boundary'**
