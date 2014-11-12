There are three main parts:
-  the web server interface
-  fetch, which manages the downloads request to various sites/service (e.g. Ensembl)
-  dispatch, which sends a job ready to be executed to a well-built server running [PIntron](http://pintron.algolab.eu)

##Web Interface

The user will select:

  1.  an organism. Default is "human", while "unknown" is a possible choice.
  2.  a gene. Default is "unknown".
  3.  whether we must download the known transcripts from Ensembl
  4.  a genomic sequence. Three possible choices:
      *  download from Ensembl (default if organism and gene are not "unknown")
      *  url of a FASTA file (tipically the share link from Dropbox or Figshare)
      *  upload of a FASTA file
  5. a set of ESTs or RNA-Seqs. Two possible choices:
      *  url of a FASTA file (tipically the share link from Dropbox or Figshare)
      *  upload of a FASTA file

If the request is satisfied within a minute, then it is displayed on screen. Otherwise the user is warned that the request is taking longer, and an email is sent with a link to the computed results. The user can wait for the results, if he wants so.

The genomic sequence to download from Ensembl must be larger than the one given by default by Ensembl, as it must contain also additional 30k base pairs before and after the default gene sequence.

##Fetch

It is responsibility of FETCH to download all required files from Ensembl or other sources

##Dispatch

It is responsibility of DISPATCH to determine if all downloads have been completed and to send the request to the highest-priority server that has some slots available.
