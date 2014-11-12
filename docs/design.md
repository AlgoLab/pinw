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
      *  url of a FASTA or FASTQ file (tipically the share link from Dropbox or Figshare)
      *  upload of a FASTA or FASTQ file
  6. the threshold of the minimum acceptable quality of a base

If the request is satisfied within a minute, then it is displayed on screen. Otherwise the user is warned that the request is taking longer, and an email is sent with a link to the computed results. The user can wait for the results, if he wants so.

The genomic sequence to download from Ensembl must be larger than the one given by default by Ensembl, as it must contain also additional 30k base pairs before and after the default gene sequence. 
The genomic sequence (it does not matter its origin) must have a header conforming with pintron specification.

The results can be shown even if the transcripts have not been downloaded (due to a permanent or temporary error).

###Questions

It is responsibility of the web interface to check the database to verify if a job has completed and to display the results. If necessary, it should also send an email.

##Fetch

It is responsibility of FETCH to download all required files from Ensembl or other sources

##Dispatch

It is responsibility of DISPATCH to determine if all downloads have been completed and to send the request to the highest-priority server that has some slots available.

The request consists of:
  1. copying all input files (via scp or rsync)
  2. sending and executing a script on the remote server that:
    * checks if the files have been transferred correctly (md5 checksum)?
    * invokes pintron
    * updates the database to signal that the processing has been completed
