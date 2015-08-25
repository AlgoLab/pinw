## Top-level Hash
      
|Key               |Value                                                             | 
|:------------------|:-----------------------------------------------------------------|
|sequence_id        |FASTA header (first line) of the `genomic.txt` file. The leading `>` is ecluded  
|program_version    |pipeline version
|file_format_version|JSON schema version  
|regions            |sorted array
|boundaries         |sorted array
|exons              |array
|introns            |array
|isoforms           |array
 
*********************************************************************************************************************************  
## Regions

A *region* is a maximal interval of positions on the genomic region such that no intron/exon
border lies in a region.
In other words, each position is part of the coding region of the same
set of isoforms.
This can happen in any of the following cases:

1. A region is included in all isoforms -->> conserved coding region
2. A region is included in some, but not all, isoforms -->>
alternatively coding region
3. No position of a region is included in an isoform -->> noncoding
region (always a part of some introns)  
4. unknown region

Each region is a hash with the following keys:
      

|Key               |Value                                                             | 
|:-----------------|:-----------------------------------------------------------------|
|start             |initial position. 1-based and with respect to the genome  |
|end               |final position. 1-based and with respect to the genome|
|sequence          |substring of `genomic.txt`, between positions `start` and `end`|
|type              |*coding* if the region is part of an exon, *intron* if not part of any exon and is part of an intron, *unknwown" otherwise|
|alternative?      |*true* if the region is not part of an exon in at least an isoforms, *false* otherwise. It is defined only if `type` has value *coding*|
|coverage          |integer >= 0. Default value is 0 (if no value is given in input|
|last?             |*true* if it is the last region of the array|
|id                |position of the current region inside the `regions` array|
|intron number     | number of introns including the region|
|exon number       |number of exons including the region **or number of isoforms including the region|

####Notes
1. nella visualizzazione, l'altezza del rettangolo che rappresenta una regione codificante dovrebbe essere proporzionale al valore di "coverage" (solo per type="coding" e se almeno un coverage è maggiore di 0).
2. `type`="coding" if `exon number`>0. Moreover `alternative?` is *true* if `exon number` is smaller then the number of isoforms in the input JSON file.
3. `type`="intron" if `exon number`=0 and `intron number`>0
4. `type`="unknown" otherwise

 
## Boundaries

A boundary separates two consecutive regions. Those two regions are called *left region* and *right region*.
Each boundary is a hash with the following keys:

|Key               |Value                                                             | 
|:-----------------|:-----------------------------------------------------------------|
|lcoordinate       |`end` position of the left region
|rcoordinate       |`start` position of the right region
|first             |index of the left region inside the array `regions`
|type              |*5* if it is an exon-intron splicing site, *3* if it is an intron-exon splicing site, *both* if it is both  an exon-intron and an intron-exon splicing site, *init* if it starts the transcription, *term* if it end the transcription, *unknown* otherwise

####Notes
0. rcoordinate = lcoordinate + 1
1. regions[first + 1] is the right region, ```if not regions[first][last?]```
2. `type` = "5" if the right region has `exon number`=0 and `intron
   number`>0, while the left
   region has `exon number`>0, that is the boundary is an exon-intron
   splicing site.
3. `type` = "3" if the right region has `exon number`>0, while  the left
   region has `exon number`=0  and `intron number`>0, that is the
   boundary is an intron-exon splicing site.
3. `type` = "both" if the left and right regions both have  `exon
   number`>0 and `intron number`>0, that is the
   boundary is a both and exon-intron and an intron-exon splicing site.
4. `type` = "init" (not implemented)
5. `type` = "term" if there exists an isoform such that `polyA` is
*true* and the current region is the last region of the last exon
6. if `first`=-1 then there exists no left region. The current
boundary can only be *unknown* or *init*. Since *init* is not
implemented yet, it is *init*
7. if ```regions[first][last?]```, then there exists no right region.
The current boundary can only be *unknown* or *term*.
8. ```if regions[first][type] == "unknown"``` then 'type' is "unknown" or "init"
9. ```if regions[first+1][type] == "unknown"``` then 'type' is "unknown" or "term"
            


1. se una delle due regioni che definiscono il boundary e' unknown
   (sicuramente non entrambe), il boundary non e' sicuramente uno
   splice site. Questo corrisponde al fatto che una rcoordinate non
   trova una lcoordinate che sia minore, oppure che una lcoordinate
   non abbia una rcoordinate che sia maggiore.

###Procedures:

1. Per ogni introne o esone, siano [s,e] rispettivamente i valori di
“relative start” e  “relative end”.
2. Si aggiungono i boundaries [s-1, s] e [e, e+1]


Una regione ha come “start” una lcoordinate e per “end” la rcoordinate
minima fra tutte quelle maggiori di “start”.
Se non esiste una rcoordinate con valore maggiore di "start", allora
si scarta il valore di "start".


Una scansione degli introni e delle isoforme del json di pintron permette di calcolare per ogni regione, i valori di “intron number” e “exon number”, per ogni boundary il valore di “first”




Gli altri campi mi sembrano immediati da calcolare.

###Exons  
 
Each exon is a hash with the following keys:
|Key               |Value                                                             | 
|:-----------------|:-----------------------------------------------------------------|
|left_boundary     |index of the start position of the current exon inside the `boundaries` array
|right_boundary    |index of the end position of the current exon inside the `boundaries` array  
|annotated?        |*true* if the exon is annotated, *false* otherwise
|start             |start position of the exon
|end               |end position of the exon
                      
####Notes
1.   ```regions[boundaries[left_boundary][first] + 1][type] == "coding"```
2.   ```regions[boundaries[left_boundary][first] + 1] == start```
3.   ```regions[boundaries[right_boundary][first]][type] == "coding"```
4.   ```regions[boundaries[right_boundary][first]] == end```
3.   Se "type" di L e' "unknown" allora l'esone sara' incompleto a
     sinistra (NB: se non e' "unknown, allora puo' essere solo "3", "both", o "init) **cosa vuole dire incompleto?**
4.   Se "type" di R e' "unknown" allora l'esone sara' incompleto a
     destra (NB: se non e' "unknown, allora puo' essere solo "5", "both", o "term)
5.   La sequenza nucleotidica dell'esone e' ottenuta concatenando le
sequenze delle regioni di indice s, s+1, ..., e dove s coincide con
l'indice della regione di destra del left boundary ed e coincide con
l'indice della regione di sinistra del right boundary; tutte queste
regioni non possono avere "type" diverso da "coding" (cioe' devono
essere tutte codificanti). Se una di queste regioni ha "sequence"
nulla, allora non e' possibile fornire la sequenza dell'esone.

##Introns

Each intron is a hash with the following keys:

|Key               |Value                                                             | 
|:-----------------|:-----------------------------------------------------------------|
|left_boundary     |index of the start position of the current intron inside the `boundaries` array
|right_boundary    |index of the end position of the current intron inside the `boundaries` array
|prefix            |prefix sequence **a cosa serve?**
|suffix            |suffix sequence **a cosa serve?**
 
 ####Notes
 
 1. Il left boundary L deve avere una regione di destra con "type"="coding"|"spliced" (cioe' non puo' essere unknown; se "type"="coding" allora deve essere "alternative?"=true); il suo "start" coincide con lo start  dell'introne  
 2. Il right boundary R deve avere una regione di sinistra con "type"="coding"|"spliced" (cioe' non puo' essere  unknown; se "type"="coding" allora deve essere "alternative?"=true); il suo "end" coincide con  l'end dell'introne  
 3. "type" di L puo' essere solo "5" oppure "both"  
 4. "type" di R puo' essere solo "3" oppure "both"  
 5. La sequenza nucleotidica dell'introne e' ottenuta concatenando le sequenze delle regioni di indice s, s+1, ..., e  dove s coincide con l'indice della regione di destra del left boundary ed e coincide con l'indice della regione  di sinistra del right boundary; tutte queste regioni non possono avere "type" uguale a "unknown".  Le regioni con "type"="coding" (cioe' le regioni codificanti) devono necessariamente avere "alternative?"=true (cioe' devono essere alternative). Se una di queste regioni ha "sequence" nulla, allora la sequenza dell'introne non e' determinabile.  
 6. "prefix"/"suffix" coincidono con un prefisso/suffisso della sequenza determinata secondo (5)  
 7. Il pattern dell'introne e' dato dai primi due simboli di "prefix" e dagli ultimi due simboli di "suffix"  
    
##Isoforms

Each isoform is an array of the indices of the regions forming the exons of the isoform. **perchè non l'array degli esoni**

####Notes

1. all regions in an isoforms must have ```type="coding"```
                    
**prendo direttamente tutte le isoforme dal json di pintron? non ho ben capito come è strutturato l'elemento dell'array. Oltre alla chiave type le altre chiavi come si chiamano? 'left_boundary' e 'right_boundary'**
