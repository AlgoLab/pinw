Jobs
====


* Organism
* Gene
* Genomics

  * Download from ENSEMBL
  * Download a FASTA file from a URL
  * Upload a FASTA file
* Sequence

  * FASTA
  * ESTs
* Job Description

Organism
--------
Selezionare il tipo di organismo del gene dal menu a tendina, nel caso non si conoscesse si può inserire "Unknown", l'admin può inserire nuovi organismi tramite la pagina apposita nel pannello di amministrazione


Gene Name
---------
Inserire il nome del gene, nel caso non si conoscesse si può lasciare il campo vuoto, l’applicazione tenterà di ricavare il nome tramite
l’header presente nel file fasta utilizzando le API messe a disposizione da Ensembl.

Genomics
--------
La sequenza genomica può essere scaricata automaticamente tramite le API di Ensembl se si è inserito l'organismo e il nome del gene,
oppure inserendo l'indirizzo web dove è presente il file o in alternativa caricare il file presente sul proprio PC.

Sequences
---------
La sequenza può essere di due tipi ESTs o FASTQ (non ancora supportata da Pintron) 
Anche in questo caso è possibile inserire l’indirizzo web dove è
presente il file da scaricare oppure caricare il file presente sul proprio PC, è possibile
inserire più sequenze utilizzando l’apposito pulsante avente l’icona del +