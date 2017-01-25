Installazione
=============
L'installazione di Pinw richiede che Ruby sia correttamente installato e funzionante.

Installazione con Docker
----------
Per l'installazione viene messo a disposizione un Dockerfile per effettuare il deploy.

Per maggiori informazioni visitare:  `Pinw Deploy <https://github.com/AlgoLab/pinw-deploy/>`_


Installazione senza Docker
------------
Se non si vuole utilizzare Docker, si può procedere con l'installazione manuale per lo sviluppo in locale.
Aprire il terminale e seguire le seguenti istruzioni:  

::

  $ git clone https://github.com/AlgoLab/pinw.git
  $ cd pinw

Per installare tutte le gemme necessarie è possibile utilizzare la gemma `Bundler <https://bundler.io/>`_    
(Visitare il link per l'installazione di Bundler)
::

  $ bundle install

Inizializzare e popolare il database
::
  $ rake db:setup

Avviare i Cronjobs
::
  $ whenever -w

Avviare il server di test
::
  $ rackup

Visitare la pagina
::
  http://localhost:9292/

Accedere con i seguenti dati:
::
   Username: admin
   Password: admin