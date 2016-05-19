var width;

$(document).ready(function() {

  //margini
  margin_isoform = {top: 100, right: 15, bottom: 15, left: 10};

  //dimensione della finestra di visualizzazione dell'isoforma
  height = window.innerHeight + 100 - margin_isoform.top - margin_isoform.bottom;
  //var width = window.innerWidth;
  width = $('#viz-block').width();
  width_isoform = $('#isoform-block').width();
  height_isoform = 250;
  margin_left=$('#isoform-block').position().left;

  //dimensioni fisse della finestra degli elementi selezionati (struttura espansa)
  s_w = width;
  s_h = 300;

  //flag per segnalare l'attivazione della struttura, dello zoom e
  //della presenza della sequenza nucleotidica
  flag_structure = false;
  flag_zoom = false;
  flag_sequence = false;
  flag_exon = true;

 
  //stringa per il nome del gene da visualizzare
  string_gene =  $("#result_gene").data("gene"); //"ATP6AP1";
  //stringa per il pathname del file json
  default_structure = $("#result_json").data("json");  //"ATP6AP1example2.json";



   setup_interface();

});
