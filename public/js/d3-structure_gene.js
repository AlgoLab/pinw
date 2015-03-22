
/* D3 Inteface of structure gene (https://bitbucket.org/Andre_T)
 * 
 * Copyright (C) 2014 Andrea Tornaghi
 * Licensed under GPLv3 (http://www.gnu.org/licenses/gpl.html)
 */


//margini
var margin_isoform = {top: 100, right: 15, bottom: 15, left: 10};

//dimensione della finestra di visualizzazione dell'isoforma
var height = window.innerHeight + 100 - margin_isoform.top - margin_isoform.bottom;
var width = window.innerWidth;
var width_isoform = 300;
var height_isoform = 250;

//dimensioni fisse della finestra degli elementi selezionati (struttura espansa)
var s_w = width - margin_isoform.left - margin_isoform.right;
var s_h = 300;

//flag per segnalare l'attivazione della struttura, dello zoom e 
//della presenza della sequenza nucleotidica
var flag_structure = false, flag_zoom = false, flag_sequence = false, flag_exon = true;

//stringa per il nome del gene da visualizzare
var string_gene = "ATP6AP1";
//stringa per il pathname del file json
var default_structure = "ATP6AP1example2.json";


//rimuove i duplicati da un array (indipendente dal tipo di elemento)
var remove_duplicate = function(a) {
	
	var new_a = [], a_l = a.length, found, x, y;
	
	for (x = 0; x < a_l; x++){
		found = undefined;
		for (y = 0; y < new_a.length; y++){
			if (a[x] === new_a[y]){
				found = true;
        		break;
            }
        }
        if (!found) {
            new_a.push(a[x]);
        }
    }
    return new_a;
 };
 
 //funzione per lo zoom della struttura genica
 var zoom_isoform = d3.behavior.zoom()
 	.scaleExtent([1.5, 3])
  	.on("zoom", zoom);
//funzione per traslare e scalare la struttura genica
//in base alle coordinate del mouse 
function zoom() {
 	svg_isoform.attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")");
 }


/* EXONS_STRUCTURE
 * extract_exons -> dati degli esoni estratti dal file json
 * extract_regions -> dati delle regioni estratti dal file json
 * extract_boundary -> dati dei boundaries estratti dal file json
 * 
 * Crea la struttura dei dati per gli esoni. Concatena le sequenze
 * nucleotidiche delle regioni, riporta gli ID delle regioni
 * che compongono l'esone e la lunghezza in bp di ogni esone.
 */
function exons_structure (extract_exons, extract_regions, extract_boundary) {
		
	//array di oggetti "esone"
	var exons = [];
	//numero di esoni
	var l = extract_exons.length;
	
	for (i = 0; i < l; i++) {
		var reg = [];
		//proprietà esone
		var exon_prop = {
			//left & right boundary
			l_b : extract_exons[i].left_boundary,
			r_b : extract_exons[i].right_boundary,
			annot : extract_exons[i].annotated,
			//sequenza nucleotidica
			seq : "",
			flag_seq : false,
			flag_alt : false,
		};
		
		var region_prop = {
			//regione boundary di sinistra
			r_l : extract_regions[extract_boundary[exon_prop.l_b].first + 1],
			//regione boundary di destra
			r_r : extract_regions[extract_boundary[exon_prop.r_b].first]
		};
		
		var boundary_prop = {	
			//tipologia regione di sinistra	
			t_r_l : region_prop.r_l.type,
			//tipologia regione di destra
			t_r_r : region_prop.r_r.type
		};
		
		//condizioni estratte da "propostaJSON2.txt"
		//esclude le regioni non codificanti
		if ((boundary_prop.t_r_l == "codifying") & (boundary_prop.t_r_l != "unknow")) {
			start_exon = region_prop.r_l.start;
			if ((boundary_prop.t_r_r == "codifying") & (boundary_prop.t_r_r != "unknow"))
				end_exon = region_prop.r_r.end;
			
			//assembla la sequenza nucleotidica e salva le regioni appartenenti all'esone
			for (j = region_prop.r_l.id; j <= region_prop.r_r.id; j++) {
				if (extract_regions[j].sequence == null)
					exon_prop_flag.seq = true;
				else {
					if(extract_regions[j].type == "codifying")
						exon_prop.seq = exon_prop.seq.concat(extract_regions[j].sequence);
					else 
						exon_prop.flag_seq = true;
					}
				reg.push(extract_regions[j].id);
				
				if(extract_regions[j].alternative == true)
					exon_prop.flag_alt = true;
				
			}
			
			if (exon_prop.flag_seq == true)
				exon_prop.seq = null;
				
			//assembla l'oggetto esone
			exons.push({
					"id" : i,
					"start" : start_exon,
					"end" : end_exon,
					"sequence" : exon_prop.seq,
					"regions" : reg,
					"alternative" : exon_prop.flag_alt,
					"annotated" : exon_prop.annot,
					"length" : (end_exon - start_exon + 1) + " bp"
			});
			reg = [];
		}
	}
	return exons;	
}


/* INTRONS_STRUCTURE
 * extract_introns -> dati degli introni estratti dal file json
 * extract_regions -> dati delle regioni estratti dal file json
 * extract_boundary -> dati dei boundaries estratti dal file json
 * 
 * Crea la struttura dei dati per gli introni. Concatena le sequenze
 * nucleotidiche delle regioni, riporta gli ID delle regioni
 * che compongono l'introne, calcola il pattern dai suffissi e prefissi
 * delle regioni che compongono l'introne e calcola la lunghezza
 * dellintrone in bp.
 */
function introns_structure(extract_introns, extract_regions, extract_boundary){
	
	//numero di introni
	var l = extract_introns.length;
	//array di oggetti "introne"
	var introns = [];
	
	for(i = 0; i < l; i++){
		var reg = [];
		var intron_prop = {
			//stringa per la sequenza nucleotidica
			seq : "",
			flag_seq : false,
			flag_intron_ok : true,
			//left & right boundary
			l_b : extract_introns[i].left_boundary,
			r_b : extract_introns[i].right_boundary,
			pattern : ""
		};
		
		var region_prop = {
			//regione boundary di sinistra
			r_l : extract_regions[extract_boundary[intron_prop.l_b].first + 1],
			//regione boundary di destra
			r_r : extract_regions[extract_boundary[intron_prop.r_b].first]
		};
		
		var boundary_prop = {
			//tipologia regione di sinistra	
			t_r_l : region_prop.r_l.type,
			//alternative
			a_r_l : region_prop.r_l.alternative,
			//tipologia regione di destra
			t_r_r : region_prop.r_r.type,
			//alternative
			a_r_r : region_prop.r_r.alternative
		};
		
		//condizioni estratte da "propostaJSON2.txt"
		//esclude le regioni non codificanti
		if((boundary_prop.t_r_l != "unknow") & (boundary_prop.t_r_r != "unknow")){
			if((extract_boundary[intron_prop.l_b].type ==  "5") | (extract_boundary[intron_prop.l_b].type == "both")){
				if((boundary_prop.t_r_l == "codifying") & (boundary_prop.a_r_l == true))
					start_intron = region_prop.r_l.start;
				else
					if(boundary_prop.t_r_l == "spliced")
						start_intron = region_prop.r_l.start;
					else
						intron_prop.flag_intron_ok == false;
			}
			else
				intron_prop.flag_intron_ok = false;	
			if((extract_boundary[intron_prop.r_b].type ==  "3") | (extract_boundary[intron_prop.r_b].type == "both")){
				if((boundary_prop.t_r_r == "codifying") & (boundary_prop.a_r_r == true))
					end_intron = region_prop.r_r.end;
				else
					if(boundary_prop.t_r_r == "spliced")
						end_intron = region_prop.r_r.end;
					else
						intron_prop.flag_intron_ok = false;
			}
			else
				intron_prop.flag_intron_ok = false;
		}
		else
			intron_prop.flag_intron_ok = false;
				
		if(intron_prop.flag_intron_ok){
			//assembla la sequenza nucleotidica e salva le regioni appartenenti all'introne
			for(j = region_prop.r_l.id; j <= region_prop.r_r.id; j++){
			
				if(extract_regions[j].sequence == null)
					intron_prop.flag_seq = true;
				else{
					if(((extract_regions[j].type == "codifying") & (extract_regions[j].alternative == true)) | extract_regions[j].type == "spliced")
						intron_prop.seq = intron_prop.seq.concat(extract_regions[j].sequence);
					else
						intron_prop.flag_seq = true;
					}
			
				reg.push(extract_regions[j].id);
			}
			
		    if(intron_prop.flag_seq == true)
				intron_prop.seq = null;
		
		    //suffisso e prefisso della sequenza nucleotidica
			var l_suffix = extract_introns[i].suffix.length;
			intron_prop.pattern = extract_introns[i].prefix.substr(0, 2).concat(extract_introns[i].suffix.substr(l_suffix - 2, l_suffix));
			
			//assembla l'oggetto introne
			introns.push({
					"start" : start_intron,
					"end" : end_intron,
					"sequence" : intron_prop.seq,
					"suffix" : extract_introns[i].suffix,
					"prefix" : extract_introns[i].prefix,
					"pattern" : intron_prop.pattern,
					"regions" : reg,
					"id" : i,
					"length" : (end_intron - start_intron + 1) + " bp"
			});
			reg = [];		
		}	
	}	
	return introns;	
}


/* SPLICE_SITES_STRUCTURE
 * extract_boundaries -> dati dei boundary estratti dal file json
 * extract_regions -> dati delle regioni estratti dal file json
 * 
 * Crea la struttura dei dati per gli splice_sites. Riporta la posizione
 * e la tipologia di ogni splice_sites 
 */
function splice_site_structure(extract_boundaries, extract_regions){
	
	//numero dei boundaries
	var l = extract_boundaries.length;
	//array di oggetti "splice sites"
	var s_s = [];
	
	var boundary_prop = {
		//posizione
		pos : null,
		//tipologia
		t : ""
	};
	
	//condizioni estratte da "propostaJSON2.txt"
	for(i = 0; i < l; i++){
		if(extract_boundaries[i].first == -1){
			boundary_prop.pos = null;
			boundary_prop.t = "unknow";
		}	
		else{
			boundary_prop.t = extract_boundaries[i].type;	
			if((boundary_prop.t == "5") | (boundary_prop.t == "both"))
				boundary_prop.pos = extract_regions[extract_boundaries[i].first + 1].start;
			if((boundary_prop.t == "3") | (boundary_prop.t == "term"))
				boundary_prop.pos = extract_regions[extract_boundaries[i].first].end;
			if(boundary_prop.t == "init")
				boundary_prop.pos = extract_regions[extract_boundaries[i].first].start;
						
			//assembla l'oggetto splice sites
			s_s.push({
				"position" : boundary_prop.pos,
				"type" : boundary_prop.t,
				"id" : i			
			});
		}
	}	
	return s_s;
}


/* ISOFORM_RANGE
 * reg -> dati delle regioni estratti dal file json
 * 
 * Definisce un range per trasformare la posizione (start & end) 
 * dei blocchi nell'isoforma in coordinate della finestra 
 * di visualizzazione.
 */
function isoform_range(reg) {
	
	//range per la finestra della struttura
	var x = d3.scale.log()
		.rangeRound([0, width - width_isoform - margin_isoform.left - margin_isoform.right], .1);				
	//valorei minimo e massimo di inizio e fine dei blocchi
	var min = d3.min(reg, function(d) { return d.start; });
	var max = d3.max(reg, function(d) { return d.end; });
	
	x.domain([min, max], .1);
	
	return x;
}


/* SET_SVG
 * c -> classe
 * w -> width
 * h -> height
 * p -> array per la posizione
 * 
 * Crea un elemento "svg", specificando la posizione, 
 * la dimensione e la classe
 */
function set_svg(c, w, h, p){
	
	var svg = d3.select("body").append("svg")
		.attr("id", c)
		.attr("width", w)
		.attr("height", h)
		.style("position", p.pos)
		.style("left", p.left)
		.style("right", p.right)
		.style("top", p.top);	
	
	return svg;
}


/* EXPANDE_BOX_RANGE (DEPRECATED)
 * reg -> regioni dell'esone selezionato
 * h_info -> altezza finestra 
 * 
 * Ritorna una funzione che riscala ogni valore nel range 
 * della finestra di visualizzazione.
 * Non viene utilizzata nelle versione più recente perchè
 * la finestra della struttura espansa ha la stessa dimensione
 * della finestra dell'isoforma
 */
function expande_box_range(reg, w_info){
	
	//range per la finestra degli elementi selezionati
    y = d3.scale.log()
    	.rangeRound([0, w_info], .1);
                
    //valorei minimo e massimo di inizio e fine dei blocchi
    var min_r = d3.min(reg[0], function(d) { return d.start; });
    var max_r = d3.max(reg[0], function(d) { return d.end; });
    
    if(reg.length > 1){
    	min_i = d3.min(reg[1], function(d) { return d.start; });
        max_i = d3.max(reg[1], function(d) { return d.end; });
    }
    else{
        min_i = min_r;
        max_i = max_r;
    }
    
    if(min_r <= min_i)
        min = min_r;
    else
        min = min_i; 
    
    if(max_r >= max_i)
        max = max_r;
    else
        max = max_i;
    
    y.domain([min, max], .1);
    
    return y;
}


/* LEGEND_BOX
 * 
 * Visualizza la legenda per gli elementi delle struttura
 * del gene
 */
function legend_box(){
	
	//bordo della finestra SVG
	border_width = 8;
	
    //dimensioni fisse degli elementi della legenda
    l_w = width_isoform - margin_isoform.right - margin_isoform.left - border_width;
    var l_h = 250;
    var off_set = 80;
    var off_set_y = 25;
    var height_exon = 18;
    
    //durata e ritardo animazione
    var t = 750, d = 1500;
    
    //struttura per il posizionamento            
    var p_s = {
    	pos : "absolute", 
    	left : (width - width_isoform + margin_isoform.left + border_width) +  "px",
    	right : margin_isoform.right + "px",
    	top: "60px", 
    	bottom : "10px"
    };
       
    //variabile per traslare gli elementi
	var tf_element = d3.svg.transform()
		.translate(function () { return [20, 26]; });
	var tf_text = d3.svg.transform()
		.translate(function () { return [20, 30]; });
	
	var color_exon = function() { return d3.rgb("#228B22"); };
	var color_exon_stripe = function() { return 'url(#diagonalHatch)'; };
    var color_intron = function() { return d3.rgb("black"); };
    var color_splice_site = function() { return d3.rgb("black"); };
                                        
    //dichiarazione della finestra SVG
    var s_l = set_svg("legend", l_w, l_h, p_s);
   
    //"viewbox" rimappa le coordinate della finestra all'interno dei 
    //valori specificati dal risultato della funzione
    s_l.attr("viewbox", function() { return "0 0" + l_w + l_h; });

    //tipologia regioni
    s_l.append("rect")
    	.attr("x", 0)
    	.attr("y", 0)
    	.attr("width", 40)
    	.attr("height", height_exon)
    	.attr("transform", tf_element)
    	.style("fill", color_exon)
    	.style("opacity", "0.0")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    s_l.append("text")
    	.attr("x", off_set)
    	.attr("y", height_exon/2)
    	.style("font-size", "13px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.style("opacity", "0.0")
    	.attr("transform", tf_text)
    	.text("Alternative region")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    
    s_l.append("rect")
    	.attr("x", 0)
    	.attr("y", off_set_y)
    	.attr("width", 40)
    	.attr("height", height_exon)
    	.attr("transform", tf_element)
    	.style("fill", color_exon)
    	.style("opacity", "0.0")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    s_l.append("rect")
    	.attr("x", 0)
    	.attr("y", off_set_y)
    	.attr("width", 40)
    	.attr("height", height_exon)
    	.attr("transform", tf_element)
    	.style("fill", color_exon_stripe)
    	.style("opacity", "0.0")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    s_l.append("text")
    	.attr("x", off_set)
    	.attr("y", height_exon/2 + off_set_y)
    	.style("font-size", "13px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.style("opacity", "0.0")
    	.attr("transform", tf_text)
    	.text("Conserved region")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    
    //tipologia introni	
    s_l.append("line")
    	.attr("x1", 0)
    	.attr("y1", off_set_y*2 + 20)
		.attr("x2", 40)
		.attr("y2", off_set_y*2 + 20)
    	.attr("transform", tf_element)
    	.style("stroke", color_intron)
    	.style("stroke-width", 6)
    	.style("opacity", "0.0")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    s_l.append("text")
    	.attr("x", off_set)
    	.attr("y", off_set_y*2 + 20)
    	.style("font-size", "13px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.style("opacity", "0.0")
    	.attr("transform", tf_text)
    	.text("Intron")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    
    //tipologia splice sites 
    var s_sy = d3.svg.symbol()
		.type('triangle-up')
		.size(10);
	//tipo 3'
    s_l.append("line")
    	.attr("x1", 0)
    	.attr("y1", off_set_y * 3.8)
		.attr("x2", 0)
		.attr("y2", off_set_y * 3.8 + 20)
    	.attr("transform", tf_element)
    	.style("stroke", color_intron)
    	.style("stroke-width", 2)
    	.style("opacity", "0.0")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");	
	
	var position_t = 22;									
	s_l.append("path")
		.attr("d", s_sy)
		.attr("fill", "none")
		.attr("stroke","black")
		.attr("stroke-width", "1px")
		.style("opacity", "0.0")
		.attr("transform", function () {
							 return "translate(" + position_t + "," + (off_set_y * 3.8 + 24) + ")" + "rotate(90)";  })
		.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
	s_l.append("path")
		.attr("d", s_sy)
		.attr("fill", "none")
		.attr("stroke","black")
		.attr("stroke-width", "1px")
		.style("opacity", "0.0")
		.attr("transform", function () {
							 return "translate(" + position_t + "," + (off_set_y * 3.8 + 47) + ")" + "rotate(90)";  })
		.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
	    
	s_l.append("text")
    	.attr("x", off_set)
    	.attr("y", off_set_y * 3.8 + 10)
    	.style("font-size", "13px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.style("opacity", "0.0")
    	.attr("transform", tf_text)
    	.text("5' Splice site").transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0"); 
	    
	//tipo 5'
    s_l.append("line")
    	.attr("x1", 0)
    	.attr("y1", off_set_y * 5)
		.attr("x2", 0)
		.attr("y2", off_set_y * 5 + 20)
    	.attr("transform", tf_element)
    	.style("stroke", color_intron)
    	.style("stroke-width", 2)
    	.style("opacity", "0.0")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");	
	
	position_t = 18;									
	s_l.append("path")
		.attr("d", s_sy)
		.attr("fill", "none")
		.attr("stroke","black")
		.attr("stroke-width", "1px")
		.style("opacity", "0.0")
		.attr("transform", function () {
							 return "translate(" + position_t + "," + (off_set_y * 5 + 24) + ")" + "rotate(-90)";  })
		.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
	s_l.append("path")
		.attr("d", s_sy)
		.attr("fill", "none")
		.attr("stroke","black")
		.attr("stroke-width", "1px")
		.style("opacity", "0.0")
		.attr("transform", function () {
							 return "translate(" + position_t + "," + (off_set_y * 5 + 47) + ")" + "rotate(-90)";  })
		.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
	s_l.append("text")
    	.attr("x", off_set)
    	.attr("y", off_set_y * 5 + 10)
    	.style("font-size", "13px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.style("opacity", "0.0")
    	.attr("transform", tf_text)
    	.text("3' Splice site").transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
	    
	 //tipologia esoni
    s_l.append("rect")
    	.attr("x", 0)
    	.attr("y", off_set_y * 6.5)
    	.attr("width", 40)
    	.attr("height", height_exon)
    	.attr("transform", tf_element)
    	.style("fill", function() { return d3.rgb("#ADD8E6"); })
    	.style("opacity", "0.0")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    s_l.append("text")
    	.attr("x", off_set)
    	.attr("y", off_set_y * 6.5 + height_exon/2)
    	.style("font-size", "13px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.style("opacity", "0.0")
    	.attr("transform", tf_text)
    	.text("Novel exon")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    
    s_l.append("rect")
    	.attr("x", 0)
    	.attr("y", off_set_y * 7.5)
    	.attr("width", 40)
    	.attr("height", height_exon)
    	.attr("transform", tf_element)
    	.style("fill", function() { return d3.rgb("#ADD8E6"); })
    	.style("stroke", function() { return d3.rgb("#00008B"); })
    	.style("stroke-width", "3px")
    	.style("opacity", "0.0")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
    s_l.append("text")
    	.attr("x", off_set)
    	.attr("y", height_exon/2 + off_set_y * 7.5)
    	.style("font-size", "13px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.style("opacity", "0.0")
    	.attr("transform", tf_text)
    	.text("Annotated exon")
    	.transition()
	    .delay(d)
	    .duration(t)
	    .style("opacity", "1.0");
}


/* REMOVE_ELEMENT_EXPANDE_BOX
 * 
 * Funzione eseguita alla pressione del tasto "Reset", alla
 * selezione di un nuovo gene e al click sul nome del gene
 * nella navigation bar. Elimina tutti gli elementi nella
 * finestra della struttura espansa. Ripristina le dimensioni
 * originali della struttura e tutte le sue funzioni, disabilita
 * lo zoom.
 */
function remove_element_expande_box(){
	
	//durata animazione
	var t = 750;
	
	d3.select("#zoom_button_on")
    	.attr("class", "btn btn-default");
	
	//rimozione segnalatore click del mouse
	d3.selectAll("#cross_pos").remove();
	
	//ripristino esoni "conservated"
	d3.selectAll("#exon")
    	.transition()
        .duration(750)
        .style("opacity","1.0")
    	.attr("pointer-events", "yes")
      	.style("stroke-width", 0)
      	.style("fill", function() { return d3.rgb("#228B22"); });
    
    //ripristino esoni "alternative"                               
    d3.selectAll("#exon_stripe")
    	.transition()
        .duration(t)
        .style("opacity","1.0")
    	.attr("pointer-events", "yes")
        .style("stroke-width", 0)
        .style("fill", 'url(#diagonalHatch)');
    d3.select("#exon_stripe_over")
    	.transition()
        .duration(t)
        .style("opacity", "0.0")
    	.remove();                    
    d3.selectAll("#exon_stripes")
    	.transition()
        .duration(t)
        .style("opacity","1.0")
    	.attr("pointer-events", "yes")
        .style("stroke-width", 0)
        .style("fill", function() { return d3.rgb("#228B22"); });
    
    //ripristino introni                    
    d3.selectAll("#intron")
    	.transition()
        .duration(t)
        .style("opacity","1.0")
    	.style("stroke", "black")
    	.attr("pointer-events", "yes");
    
    //ripristino splice sites
    var s;
    for(s = 0; s < s_s_restruct.length; s++){
    	d3.select("#s_s_" + s_s_restruct[s].id)
    		.transition()
        	.duration(t)
        	.style("opacity","1.0")
    		.style("stroke", "black")
    		.style("stroke-width", "1px");
    	d3.select("#up_" + (s_s_restruct[s].id - 1))
            .transition()
        	.duration(t)
        	.style("opacity","1.0")
    		.style("stroke", "black");
        d3.select("#down_" + (s_s_restruct[s].id - 1))
            .transition()
        	.duration(t)
        	.style("opacity","1.0")
    		.style("stroke", "black");
    }
	
	//rimizione struttura espansa
	d3.select("#regions_selected")
		.transition()
    	.duration(t)
    	.style("opacity", "0.0")
		.remove(); 
	
	//rimozione elementi aggiunti
	d3.selectAll("#exon_s")
		.transition()
    	.duration(t)
    	.style("opacity", "0.0")
		.remove();	
	d3.selectAll("#intron_s")
		.transition()
    	.duration(t)
    	.style("opacity", "0.0")
		.remove();
    
    //rimozione sequenza nucleotidica                    		    
    d3.select("#title_sequence")
    	.transition()
    	.duration(t)
    	.style("opacity", "0.0")
    	.remove();    
    d3.select("#sequence_ex")
    	.transition()
    	.duration(t)
    	.style("opacity", "0.0")
    	.remove();
    d3.select("#sequence_in")
    	.transition()
    	.duration(t)
    	.style("opacity", "0.0")
    	.remove();
    d3.select("#table_title")
    	.transition()
    	.duration(t)
    	.style("opacity", "0.0")
    	.remove();
    d3.select("#table_start")
    	.transition()
    	.duration(t)
    	.style("opacity", "0.0")
    	.remove();
    d3.select("#table_end")
    	.transition()
    	.duration(t)
    	.style("opacity", "0.0")
    	.remove(); 
    
    flag_structure = false;
    flag_sequence = false;
}


/* BUTTONS
 * 
 * Configura i pulsanti per il reset e lo zoom della struttura.
 */
function buttons(){
	
	//durata animazione
	var d = 450;
	
	//pulsante per cancellare il contenuto della finestra della struttura
	// espansa e riattivare la struttura del gene
	d3.select("#reset_button") 
    	.style("position", "relative")
    	.style("top", "10px")   	
        .on("click", function() {
        				remove_element_expande_box();
        				//riporta la struttura genica alle dimensioni originali
        				zoom_isoform.translate([0, 0]).scale(1);
        				svg_isoform.transition()
        					.duration(d)
        					.attr("transform", "translate(" + zoom_isoform.translate() + ")scale(" + zoom_isoform.scale() + ")");
        				}
        	);
    //pulsante per attivare la funzione di zoom
    d3.select("#zoom_button_on")
   		.style("position", "relative")
    	.style("top", "10px")
        .on("click", function() {
        				//non compatibile con tutti i browser!
        				svg_isoform.style("cursor", "zoom-in");
        				
        				//disabilita gli eventi mouse sulla struttura genica
        				d3.selectAll("#exon")
        					.attr("pointer-events", "none");
      					d3.selectAll("#exon_stripe")
      						.attr("pointer-events", "none");
	   					d3.select("#exon_stripe_over")
    						.attr("pointer-events", "none");                       
    					d3.selectAll("#exon_stripes")
    						.attr("pointer-events", "none");                        
    					d3.selectAll("#intron")
    						.attr("pointer-events", "none");    
        				
        				//la sequenza nucleotidica viene resa invisibile
        				//per evitare l'effetto dell'ingrandimento
        				d3.select("#title_sequence")
        					.transition()
        					.duration(d)
        					.style("opacity", "0.0");
        				d3.select("#sequence_ex")
        					.transition()
        					.duration(d)
        					.style("opacity", "0.0");
        				d3.select("#sequence_in")
        					.transition()
        					.duration(d)
        					.style("opacity", "0.0");
        				
        				d3.select("#zoom_button_on")
        					.attr("class", "btn btn-primary");
        					
        				flag_zoom = true;
        				zoom_isoform(svg_isoform); 
        				}
        	);
    
    //pulsante per disattivare lo zoom e ripristinare la struttura
    d3.select("#zoom_button_off")
   		.style("position", "relative")
    	.style("top", "10px")
        .on("click", function(){
        				//riporta la struttura genica alle dimensioni originali
        				zoom_isoform.translate([0, 0]).scale(1);
        				svg_isoform.transition()
        					.duration(d)
        					.attr("transform", "translate(" + zoom_isoform.translate() + ")scale(" + zoom_isoform.scale() + ")");
        			
        				//attiva gli eventi mouse sulla struttura genica		
        				d3.selectAll("#exon")
        					.attr("pointer-events", "yes");
      					d3.selectAll("#exon_stripe")
      						.attr("pointer-events", "yes");
	   					d3.select("#exon_stripe_over")
    						.attr("pointer-events", "yes");                       
    					d3.selectAll("#exon_stripes")
    						.attr("pointer-events", "yes");                        
    					d3.selectAll("#intron")
    						.attr("pointer-events", "yes");
    					
    					//rende visibile la sequenza nucleotidica	
        				d3.select("#title_sequence")
        					.transition()
        					.duration(d)
        					.style("opacity", "1.0");
        				d3.select("#sequence_ex")
        					.transition()
        					.duration(d)
        					.style("opacity", "1.0");
        				d3.select("#sequence_in")
        					.transition()
        					.duration(d)
        					.style("opacity", "1.0");
        				
        				d3.select("#zoom_button_on")
        					.attr("class", "btn btn-default");
        				
        				svg_isoform.style("cursor", "default");
        				
        				flag_zoom = false;
        				//disattiva gli eventi corrispondenti allo zoom
        				//nella finestra della struttura genica
        				svg_isoform.on("mousedown.zoom", null);
						svg_isoform.on("mousemove.zoom", null);
						svg_isoform.on("dblclick.zoom", null);
						svg_isoform.on("touchstart.zoom", null);
						svg_isoform.on("wheel.zoom", null);
						svg_isoform.on("mousewheel.zoom", null);
						svg_isoform.on("MozMousePixelScroll.zoom", null);
        		});   
}

/* SVG_EXPANDE_BOX
 * 
 * Crea una finestra dove saranno visualizzati gli elementi
 * appartenenti alla selezione e le rispettive informazioni
 * su "start" e "end". 
 */
function svg_expande_box(){
	    
    //oggetto per il posizionamento            
    var p_s = {
    	pos : "absolute", 
    	left : "10px",
    	right : "10px",
    	top: "320px", 
    	bottom : "10px"
    };
    
    //dichiara finestra SVG                               
    var s_i = set_svg("expande_box", s_w, s_h, p_s);
    s_i.attr("viewbox", function() { return "0 0" + s_w + s_h; })
    	.style("overflow-y", "auto");
    
    return s_i;
}


/* REGIONS_SELECT
 * c_x -> coordinate (piano X) della posizione del mouse
 *
 * Seleziona la regione che contiene le coordinate rimappate del mouse. 
 * Rimuove tutti gli elementi di una eventuale selezione precedente 
 */
function regions_select(c_x){
	
	//ad ogni click vengono visualizzati gli elementi selezionati
	//senza resettare la struttura genica
	d3.select("#regions_selected")
		.transition()
    	.duration(750)
    	.style("opacity", "0.0")
		.remove();
	
	//rimozione sequenza nucleotidica
	d3.select("#title_sequence_box")
    	.transition()
    	.duration(750)
    	.style("opacity", "0.0")
    	.remove();    
    d3.select("#sequence_ex")
    	.transition()
    	.duration(750)
    	.style("opacity", "0.0")
    	.remove();
    d3.select("#sequence_in")
    	.transition()
    	.duration(750)
    	.style("opacity", "0.0")
    	.remove();
    d3.select("#table_title")
    	.transition()
    	.duration(750)
    	.style("opacity", "0.0")
    	.remove();
    d3.select("#table_start")
    	.transition()
    	.duration(750)
    	.style("opacity", "0.0")
    	.remove();
    d3.select("#table_end")
    	.transition()
    	.duration(750)
    	.style("opacity", "0.0")
    	.remove(); 
    	
	var reg_ext;
	for(g = 0; g < regions.length; g++)
		if((c_x > (regions[g].start)) & (c_x < (regions[g].end)))
			reg_ext = regions[g];
			        	
	return reg_ext;
}



/* ELEMENT_SELECTED_EXON
 * e_i -> elemento "esone" selezionato
 * s -> posizione di "start" dell'elemento
 * e -> posizione di "end" dell'elemento
 * 
 * Disegna un nuovo esone nella stessa posizione di quello 
 * selezionato. Si ottiene così l'effetto di evidenziare 
 * solo l'esone selezionato nella struttura espansa.
 */
function element_selected_exon(e_i, s, e){
    
    //traslazione elemento
    var tf_e = d3.svg.transform()
		.translate(function () { return [s, 0]; });
    
    var ex = e_i.append("rect")
        .attr("id", "element_info_exon")
        .attr("x", s)
        .attr("y", 0)
        .attr("width", function() { return e - s; })
        .attr("height", 75)
        .style("fill", function() { return d3.rgb("#228B22").brighter(3); });
    return ex;
}


/* CONNECT_EXON
* exon -> esone sulla struttura del gene
* sequence -> sequenza del'esone
*
* Crea un link tra l'esone selezionato e la corrispondente sequenza nucleotidica
*/
function connect_exon(exon, sequence){
	
	//coordinate degli elementi da collegare	
	var xr_s = +exon.attr("x");
	var yr_s = +exon.attr("y") + +exon.attr("height") + 1;
	var xt_s = +sequence.attr("x") + 4;
	var yt_s = +sequence.attr("y") - 4;
	
	var xr_e = +exon.attr("x") + +exon.attr("width");
	var yr_e = +exon.attr("y") + +exon.attr("height") + 1;
	var xt_e = +sequence.attr("x") + sequence.text().length*5.5 + 2;
	var yt_e = +sequence.attr("y") - 4;

	//oggetto che contiente le coordinate rimappate in "source" e "target"
    point = [{ "source" : { "x" : xr_s + margin_isoform.left, "y" : yr_s}, 
    		   "target" : { "x" : xt_s + (margin_isoform.left * 20), "y" : yt_s + 135}},
    		 { "source" : { "x" : xr_e + margin_isoform.left, "y" : yr_e}, 
    		   "target" : { "x" : xt_e + (margin_isoform.left * 20), "y" : yt_e + 135}} ];
    
    //variabile contenente la funzione D3 che crea i link tra due elementi	  
    var diagonal = d3.svg.diagonal()
    	.source(function(d) { return {"x":d.source.y, "y":d.source.x}; })            
    	.target(function(d) { return {"x":d.target.y, "y":d.target.x}; })
        .projection(function(d) { return [+d.y, +d.x + 50]; });
    
    //i link vengono aggiunti solo se lo zoom è disattivato
    if(flag_zoom == false)
    	svg_isoform.selectAll(".link")
    		.data(point)
    		.enter().append("path")
    		.attr("class", "link")
    		.attr("id", "link_ex")
        	.attr("d", diagonal);      
}


/* CONNECT_INTRON
* intron -> introne sulla struttura del gene
* sequence -> sequenza del'esone
*
* Crea un link tra l'introne selezionato e la corrispondente sequenza nucleotidica
*/
function connect_intron(intron, sequence){
	
	//coordinate degli elementi da collegare
	var xr_s = +intron.attr("x1");
	var yr_s = +intron.attr("y1");
	var xt_s = +sequence.attr("x") + 4;
	var yt_s = +sequence.attr("y") - 4;
	
	var xr_e = +intron.attr("x2");
	var yr_e = +intron.attr("y2");
	var xt_e = +sequence.attr("x") + sequence.text().length*7;
	var yt_e = +sequence.attr("y") - 4;
	
	var off_set_s = off_set_ex + (margin_isoform.left * 20) - sequence.text().length*12 + 2;
	var off_set_e = off_set_ex + (margin_isoform.left * 20) - sequence.text().length*13;

    //oggetto che contiente le coordinate rimappate in "source" e "target"
    point = [{ "source" : { "x" : xr_s + margin_isoform.left, "y" : yr_s}, 
    		   "target" : { "x" : xt_s + (margin_isoform.left * 20) + off_set_s, "y" : yt_s + 135}},
    		 { "source" : { "x" : xr_e + margin_isoform.left, "y" : yr_e}, 
    		   "target" : { "x" : xt_e + (margin_isoform.left * 20) + off_set_e, "y" : yt_e + 135}} ];
    
    //variabile contenente la funzione D3 che crea i collegamenti tra due elementi		  
    var diagonal = d3.svg.diagonal()
    	.source(function(d) { return {"x":d.source.y, "y":d.source.x}; })            
    	.target(function(d) { return {"x":d.target.y, "y":d.target.x}; })
        .projection(function(d) { return [+d.y, +d.x + 50]; });
    
    //i link vengono aggiunti solo se lo zoom è disattivato
    if(flag_zoom == false)    	
    	svg_isoform.selectAll(".link")
    		.data(point)
    		.enter().append("path")
    		.attr("id", "link_in")
    		.attr("class", "link")
        	.attr("d", diagonal);      
}


/* ELEMENT_SELECTED_INTRON
 * s -> posizione di "start" dell'elemento
 * e -> posizione di "end" dell'elemento
 * 
 * Disegna un nuovo introne nella stessa posizione di quello 
 * selezionato. Si ottiene così l'effetto di evidenziare 
 * solo l'introne selezionato sulla struttura espansa.
 */
function element_selected_intron(s, e){
     
    var intron_selected = d3.select("#introns").append("line")
        .attr("id", "element_info_intron")
		.attr("x1", s)
		.attr("y1", 35)
		.attr("x2", e)
		.attr("y2", 35)
		.style("stroke", function() { return d3.rgb("black").brighter(3); })
		.style("stroke-width", 8);
		
	return intron_selected;
}


/* DISPLAY_INFO
 * s_i -> finestra creata per visualizzare le informazioni
 * x_iso -> dominio della finestra di visualizzazione degli elementi
 * 			(lo stesso della struttura genica)
 * elements -> elementi estratti dalla struttura del gene
 *             in base alla selezione.
 * r -> contenitore degli esoni
 * 
 * Visualizza gli elementi, appartenenti alla selezione sulla struttura genica, 
 * nella finestra della struttura espansa.
 */ 
function display_info(s_i, x_iso, elements, r){
    
    //elementi estratti dalla selezione
    var exons_info = elements.r_i;
    var introns_info = elements.i_i;
    
    //posizione e dimensione della tabella
    var start_table = s_w - width_isoform + margin_isoform.left + margin_isoform.right;
    var column_start = 50, column_end = 200;
    
    //valori originali delle regioni
    var o_s = {
		exons : original_structure(original_regions, 'exon'),
		introns: original_structure(original_regions, 'intron')
	};
	
	
    //colori degli elementi
    var color_exon = function() { return d3.rgb("#ADD8E6"); };
    var color_intron = function() { return d3.rgb("black"); };
          
    //variabili per le operazioni di trasformazione 
    var transf = {	
    	//traslazione esoni   
   		t_e : d3.svg.transform()
        	.translate(function (d, i) { return [x_iso(d.start), i * 45]; }),
        //traslazione introni
    	t_i : d3.svg.transform()
        	.translate(function (d, i) { return [0, (i * 20) + (exons_info.length * 45)]; }),
        //traslazione contenitore elementi 
    	tf_g : d3.svg.transform()
        	.translate(function () { return [10, 20]; }),
        tf_table_title : d3.svg.transform()
        	.translate(function () { return [start_table, 0]; }),
        tf_table_start : d3.svg.transform()
        	.translate(function () { return [start_table, 35]; }),
        tf_table_end : d3.svg.transform()
        	.translate(function () { return [start_table, 35]; })
       };
      
    var table_text = [];
    //crea il vettore contenente le informazioni degli esoni
    for(k = 0; k < exons_info.length; k++)
    	table_text.push(exons_info[k]);  	
    //crea il vettore contenente le informazioni degli introni
    if(introns_info != null)
    	for(k = 0; k < introns_info.length; k++)
    		table_text.push(introns_info[k]);
    
    //se exons_info è NULL significa che il click è stato fatto
    //sopra un introne
    if(exons_info != null){
    //esoni e introni selezionati
    var g = s_i.append("g")
        .attr("id", "regions_selected")
        .attr("transform", transf.tf_g);        
    g.selectAll("rect")
        .data(exons_info)
        .enter().append("rect")
        .attr("id", function(d) { return "r_e_" + d.id; })
        .attr("width", function(d) { return x_iso(d.end) - x_iso(d.start); })
        .attr("height", 40)
        .style("fill", color_exon)
        .style("stroke", function(d){ 
        					if(d.annotated == true)
        						return d3.rgb("#00008B");
        					else
        						return d3.rgb("white");
        					})
        .style("stroke-width", "3px")			
        .style("opacity", "0.0")
        .attr("transform", transf.t_e)
        .on("mouseover", function(d) { 
                            d3.select(this).style('cursor', 'context-menu');
                            //esone selezionato nella struttura
                            var s = element_selected_exon(r, x_iso(d.start), x_iso(d.end));
                            
                            seq_id = "#sequence_ex_" + d.id;
                            //sequenza nucleotidica corrispondente
                            var t = d3.select(seq_id);
                            t.style("fill", "#428bca");
                            connect_exon(s, t);
                            d3.selectAll("#text_" + d.id)
                            	.style("fill", "#428bca");
                            
                            })
        .on("mouseout", function(d) { 
                            d3.select(this).style('cursor', 'default');
                            
                            //elimina la selezione
                            d3.select("#element_info_exon").remove();
                            
                            seq_id = "#sequence_ex_" + d.id;
                            d3.select(seq_id).style("fill", "black");
                            //elimina i link 
                            d3.selectAll(".link").remove();
                            d3.selectAll("#text_" + d.id)
                            	.style("fill", "black");
                           })
        .on("click", function(d) {
        	        	
        	        	//aggiunge i dati che saranno visualizzati nella
        	        	//finestra modale			
        				d3.select("#modal_body").selectAll("p")
        					.remove();
        						
        				d3.select("#modal_t").selectAll("h4")
        					.remove();
        				
        				d3.select("#modal_t").append("h4")
        					.attr("class", "modal-title")
        					.text("Exon: " + d.id);
        				d3.select("#modal_body").append("p")
        					//recupero dei valori originali
        					.text("Start: " + o_s.exons[d.id].start);
        				d3.select("#modal_body").append("p")
        					.text("End: " + o_s.exons[d.id].end);
        				d3.select("#modal_body").append("p")
        					.text("Length: " + o_s.exons[d.id].length);
        					
        				d3.select("#modal_body").append("p")
        					.text("Annotated: " + d.annotated);
        				
        				d3.select("#modal_body").append("p")
        					.text("Alternative: " + d.alternative);
        				
       					$("#myModal").modal('show');
       					
       			 	})
        .transition()
        .duration(750)
        .style("opacity","1.0");
    }
    //se introns_info è NULL nella selezione non sono presenti introni
    if(introns_info != null){
    	g.selectAll("line")
    		.data(introns_info)
			.enter().append("line")
			.attr("id", function(d) { return "i_e_" + d.id; })
			.attr("x1", function(d) { return x_iso(d.start); })
			.attr("y1", 35)
			.attr("x2", function(d) { 
							if((x_iso(d.end) - x_iso(d.start)) < 10)
								return x_iso(d.end) + 40;
							else
								return x_iso(d.end); })
			.attr("y2", 35)
			.attr("transform", transf.t_i)
			.style("stroke", color_intron)
			.style("stroke-width", 10)
			.style("opacity", "0.0")
            .on("mouseover", function(d, i) { 
                                d3.select(this).style('cursor', 'context-menu');
                                //traslazione testo pattern
                                var tf_info_text = d3.svg.transform()
                                    .translate(function () { 
                                        return [0, (i * 20) + (exons_info.length * 45)]; });
                                
                                //aggiunta del pattern agli estremi dell'introne    
                                g.append("text")
                                    .attr("x", x_iso(d.start) - 15)
                                    .attr("y", 38)
                                    .style("font-size", "10px")
                                    .attr("transform", tf_info_text)
                                    .style("font-family", "Arial, Helvetica, sans-serif")
                                    .style("fill", "#428bca")
                                    .text(d.pattern.slice(0,2).toUpperCase());
                                g.append("text")
                                    .attr("x", x_iso(d.end))
                                    .attr("y", 38)
                                    .style("font-size", "10px")
                                    .style("font-family", "Arial, Helvetica, sans-serif")
                                    .attr("transform", tf_info_text)
                                    .style("fill", "#428bca")
                                    .text(d.pattern.slice(2,4).toUpperCase());
                                
                                //elemento selezionato sulla struttura genica    
                                var s = element_selected_intron(x_iso(d.start), x_iso(d.end));
                                //sequenza nucleotidica
                                seq_id = "#sequence_in_" + d.id;
                                var t = d3.select(seq_id);
                                t.style("fill", "#428bca");
                                //link
                                connect_intron(s, t);
                                d3.selectAll("#text_" + d.id)
                            		.style("fill", "#428bca"); })
            .on("mouseout", function(d) { 
            					//rimozione elemento selezionato
                                d3.select(this).style('cursor', 'default');
                                d3.select("#element_info_intron").remove();
                                
                                //rimozione sequenza nucleotidica
                                seq_id = "#sequence_in_" + d.id;
                                d3.select(seq_id).style("fill", "black");
                                g.selectAll("text").remove();
                                
                                //rimozione link
                                d3.selectAll(".link").remove();
                                d3.selectAll("#text_" + d.id)
                            		.style("fill", "black"); })
            .on("click", function(d) {
            					
            					//aggiunge i dati che verrano visualizzati
            					//nella finestra modale
        						d3.select("#modal_body").selectAll("p")
        							.remove();
        						d3.select("#modal_t").selectAll("h4")
        							.remove();
        				
        						d3.select("#modal_t").append("h4")
        							.attr("class", "modal-title")
        							.text("Intron: " + d.id);
        						//recupero dei dati originali
        						d3.select("#modal_body").append("p")
        							.text("Start: " + o_s.introns[d.id].start);
        						d3.select("#modal_body").append("p")
        							.text("End: " + o_s.introns[d.id].end);
        						d3.select("#modal_body").append("p")
        							.text("Length: " + o_s.introns[d.id].length);
        							
        						d3.select("#modal_body").append("p")
        							.append("text")
        							.text("Prefix: ")
        							.append("text")
        							.attr("class", "text-primary")
        							.text(d.prefix.substring(0,2).toUpperCase())
        							.append("text")
        							.attr("class", "text-seq")
        							.text(d.prefix.substring(2,d.prefix.length).toUpperCase());
        						d3.select("#modal_body").append("p")
        							.append("text")
        							.text("Suffix: ")
        							.append("text")
        							.attr("class", "text-seq")
        							.text(d.suffix.substring(0,d.suffix.length-3).toUpperCase())
        							.append("text")
        							.attr("class", "text-primary") 
        							.text(d.suffix.substring(d.suffix.length-2,d.suffix.length).toUpperCase());
        						
       							$("#myModal").modal('show');
       			 		})
            .transition()
        	.duration(750)
        	.style("opacity","1.0");
	} 
	
	//aggiunge della tabella
	var table_title = s_i.append("g")
        .attr("id", "table_title")
        .attr("transform", transf.tf_table_title)
        .attr("visibility", "visible");
    
    table_title.append("text")
    	.attr("x", column_start)
    	.attr("y", 15)
    	.style("font-size", "16px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "blue")
    	.text("Start")
    	.style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
    
    table_title.append("text")
    	.attr("x", column_end)
    	.attr("y", 15)
    	.style("font-size", "16px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "blue")
    	.text("End")
    	.style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
    table_title.append("line")
    	.attr("x1", 20)
    	.attr("y1", 20)
    	.attr("x2", 260)
    	.attr("y2", 20)
    	.style("stroke", "black")
    	.style("stroke-width", "1px")
    	.style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
    	
    var table_start = s_i.append("g")
        .attr("id", "table_start")
        .attr("transform", transf.tf_table_start)
        .attr("visibility", "visible");
	
	table_start.selectAll("text")
    	.data(table_text)
    	.enter().append("text")
    	.attr("id", function(d) { return "text_" + d.id; })
    	.attr("x", function(d, i) { return (column_start - (d.start.toString().length)); })
    	.attr("y", function(d) { 
    					if(d.pattern != null)
    						return 25;
    					else
    						return 15; })
    	.attr("transform", function(d, i) { 
    						//la posizione del testo della tabella viene recuperata
    						//dall'elemento a cui corrisponde con l'attributo "transform"
    						if(d.pattern == null)
    							return "translate(0," +  i * 45 + ")";
    						else
    							return d3.select("#i_e_" + d.id).attr("transform"); 
    						})
    	.style("font-size", "16px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.text(function(d) { 
    			//recupero dei valori originali
    			if(d.pattern == null)
    				return o_s.exons[d.id].start;
    			else
    				return o_s.introns[d.id].start; })
    	.style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
    
    var table_end = s_i.append("g")
        .attr("id", "table_end")
        .attr("transform", transf.tf_table_end)
        .attr("visibility", "visible");
    
    table_end.selectAll("text")
    	.data(table_text)
    	.enter().append("text")
    	.attr("id", function(d) { return "text_" + d.id; })
    	.attr("x", function(d,i) { return (column_end - (d.start.toString().length)); })
    	.attr("y", function(d) { 
    					if(d.pattern != null)
    						return 25;
    					else
    						return 15; })
    	.attr("transform", function(d, i) { 
    						//la posizione del testo della tabella viene recuperata
    						//dall'elemento a cui corrisponde con l'attributo "transform"
    						if(d.pattern == null)
    							return "translate(0," +  i * 45 + ")";
    						else
    							return d3.select("#i_e_" + d.id).attr("transform"); 
    						})
    	.style("font-size", "16px")
    	.style("font-family", "Arial, Helvetica, sans-serif")
    	.style("fill", "black")
    	.text(function(d) { 
    			//recupero dei valori originali
    			if(d.pattern == null)
    				return o_s.exons[d.id].end;
    			else
    				return o_s.introns[d.id].end; })
    	.style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
}


/* DISPLAY_INFO_STRIPE
 * s_i -> finestra creata per visualizzare le informazioni
 * x_iso -> dominio della finestra di visualizzazione degli elementi
 * elements -> elementi estratti dalla struttura del gene
 *             in base alla selezione.
 * r -> contenitore degli esoni
 * 
 * Visualizza gli elementi, appartenenti alla selezione sulla struttura genica, 
 * nella finestra della struttura espansa (per esoni 'conservative').
 * La funzione esegue le stesse operazioni di "display_info" ma viene lanciata 
 * al click sopra un esone 'conservative' (esone con texture).
 */     
function display_info_stripe(s_i, x_iso, elements, r){
    
    //elementi estratti dalla selezione
    var exons_info = elements.r_i;
    var introns_info = elements.i_i;
    
    //posizione e dimensione della tabella
    var start_table = s_w - width_isoform + margin_isoform.left + margin_isoform.right;
    var column_start = 50, column_end = 200;
    
    //colori degli elementi
    var color_exon = function() { return d3.rgb("#ADD8E6"); };
    var color_intron = function() { return d3.rgb("black"); };
    
    var transf = {	
    	//traslazione esoni   
   		t_e : d3.svg.transform()
        	.translate(function (d, i) { return [x_iso(d.start), i * 45]; }),
        //traslazione introni
    	t_i : d3.svg.transform()
        	.translate(function (d, i) { return [0, (i * 20) + (exons_info.length * 45)]; }),
        //traslazione contenitore elementi 
    	tf_g : d3.svg.transform()
        	.translate(function (d, i) { return [15, 20]; }),
           tf_table_title : d3.svg.transform()
            .translate(function (d, i) { return [start_table, 0]; }),
        tf_table_start : d3.svg.transform()
            .translate(function (d, i) { return [start_table, 35]; }),
        tf_table_end : d3.svg.transform()
            .translate(function (d, i) { return [start_table, 35]; })
       };
       
    //esoni
    var g = s_i.append("g")
        .attr("id", "regions_selected")
        .attr("transform", transf.tf_g);        
    g.selectAll("rect")
        .data(exons_info)
        .enter().append("rect")
        .attr("width", function(d) { return x_iso(d.end) - x_iso(d.start); })
        .attr("height", 40)
        .style("fill", color_exon)
        .style("stroke", function(d){ 
        					if(d.annotated == true)
        						return d3.rgb("#00008B");
        					else
        						return d3.rgb("white");
        					})
        .style("stroke-width", "3px")
        .style("opacity", "0.0")
        .attr("transform", transf.t_e)
        .on("mouseover", function(d) { 
        					d3.select(this).style('cursor', 'context-menu');
                            var s = element_selected_exon(r, x(d.start), x(d.end)); 
                            
                            seq_id = "#sequence_ex_" + d.id;
                            var t = d3.select(seq_id);
                            t.style("fill", "#428bca");
                            connect_exon(s, t);
                            d3.selectAll("#text_" + d.id)
                            	.style("fill", "#428bca");})
        .on("mouseout", function(d) { 
        					d3.select(this).style('cursor', 'default');
        					d3.select("#element_info_exon").remove();
        					
        					seq_id = "#sequence_ex_" + d.id;
                            d3.select(seq_id).style("fill", "black");
                            d3.selectAll(".link").remove();
                            d3.selectAll("#text_" + d.id)
                            	.style("fill", "black"); })
        .on("click", function(d) {
        				d3.select("#modal_body").selectAll("p")
        					.remove();
        						
        				d3.select("#modal_t").selectAll("h4")
        					.remove();
        				
        				d3.select("#modal_t").append("h4")
        					.attr("class", "modal-title")
        					.text("Exon: " + d.id);
        				d3.select("#modal_body").append("p")
        					.text("Start: " + o_s.exons[d.id].start);
        				d3.select("#modal_body").append("p")
        					.text("End: " + o_s.exons[d.id].end);
        				d3.select("#modal_body").append("p")
        					.text("Length: " + o_s.exons[d.id].length);
        				d3.select("#modal_body").append("p")
        					.text("Annotated: " + d.annotated);
        				
        				d3.select("#modal_body").append("p")
        					.text("Alternative: " + d.alternative);
        					
       					$("#myModal").modal('show');
       			 	})
        .transition()
        .duration(750)
        .style("opacity","1.0");
    
    //introni    
    if(introns_info != null){
    	g.selectAll("line")
    		.data(introns_info)
			.enter().append("line")
			.attr("id", function(d) { return "i_e_" + d.id; })
			.attr("x1", function(d) { return x_iso(d.start); })
			.attr("y1", 35)
			.attr("x2", function(d) { 
							if((x_iso(d.end) - x_iso(d.start)) < 10)
								return x_iso(d.end) + 40;
							else
								return x_iso(d.end); })
			.attr("y2", 35)
			.attr("transform", transf.t_i)
			.style("stroke", color_intron)
			.style("stroke-width", 8)
			.style("opacity", "0.0")
			.on("mouseover", function(d, i) { 
                                d3.select(this).style('cursor', 'context-menu');
                                var s = element_selected_intron(x(d.start), x(d.end));

                                var tf_info_text = d3.svg.transform()
                                    .translate(function () { 
                                        return [0, (i * 20) + (exons_info.length * 45)]; });
                                    
                                g.append("text")
                                    .attr("x", x_iso(d.start) - 15)
                                    .attr("y", 38)
                                    .attr("font-size", "10px")
                                    .attr("transform", tf_info_text)
                                    .style("fill", "#428bca")
                                    .text(d.pattern.slice(0,2).toUpperCase());
                                g.append("text")
                                    .attr("x", x_iso(d.end))
                                    .attr("y", 38)
                                    .attr("font-size", "10px")
                                    .attr("transform", tf_info_text)
                                    .style("fill", "#428bca")
                                    .text(d.pattern.slice(2,4).toUpperCase());
                                    
                                seq_id = "#sequence_in_" + d.id;
                                var t = d3.select(seq_id);
                                t.style("fill", "#428bca");
                                connect_intron(s, t);
                                d3.selectAll("#text_" + d.id)
                            	.style("fill", "#428bca"); })
            .on("mouseout", function(d) { 
                                d3.select(this).style('cursor', 'default');
                                d3.select("#element_info_intron").remove();
                                seq_id = "#sequence_in_" + d.id;
                                d3.select(seq_id).style("fill", "black");
                                g.selectAll("text").remove();
                                d3.selectAll(".link").remove();
                                d3.selectAll("#text_" + d.id)
                            	.style("fill", "black"); })
            .on("click", function(d) {
        						d3.select("#modal_body").selectAll("p")
        							.remove();
        						d3.select("#modal_t").selectAll("h4")
        							.remove();
        				
        						d3.select("#modal_t").append("h4")
        							.attr("class", "modal-title")
        							.text("Intron: " + d.id);
        						d3.select("#modal_body").append("p")
        							.text("Start: " + o_s.introns[d.id].start);
        						d3.select("#modal_body").append("p")
        							.text("End: " + o_s.introns[d.id].end);
        						d3.select("#modal_body").append("p")
        							.text("Length: " + o_s.introns[d.id].length);
        						d3.select("#modal_body").append("p")
        							.append("text")
        							.text("Prefix: ")
        							.append("text")
        							.attr("class", "text-primary")
        							.text(d.prefix.substring(0,2).toUpperCase())
        							.append("text")
        							.attr("class", "text-seq")
        							.text(d.prefix.substring(2,d.prefix.length).toUpperCase());
        						d3.select("#modal_body").append("p")
        							.append("text")
        							.text("Suffix: ")
        							.append("text")
        							.attr("class", "text-seq")
        							.text(d.suffix.substring(0,d.suffix.length-3).toUpperCase())
        							.append("text")
        							.attr("class", "text-primary") 
        							.text(d.suffix.substring(d.suffix.length-2,d.suffix.length).toUpperCase());
        							
       							$("#myModal").modal('show');
       			 		})
            .transition()
        	.duration(750)
        	.style("opacity","1.0");   
	}   
	
	var o_s = {
		exons : original_structure(original_regions, 'exon'),
		introns: original_structure(original_regions, 'intron')
	};  
	
    var table_text = [];
    for(k = 0; k < exons_info.length; k++)
        table_text.push(exons_info[k]);
    if(introns_info != null)
        for(k = 0; k < introns_info.length; k++)
            table_text.push(introns_info[k]);
       
    var table_title = s_i.append("g")
        .attr("id", "table_title")
        .attr("transform", transf.tf_table_title)
        .attr("visibility", "visible");
    
    table_title.append("text")
        .attr("x", column_start)
        .attr("y", 15)
        .style("font-size", "16px")
        .style("font-family", "Arial, Helvetica, sans-serif")
        .style("fill", "blue")
        .text("Start")
        .style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
    
    table_title.append("text")
        .attr("x", column_end)
        .attr("y", 15)
        .style("font-size", "16px")
        .style("font-family", "Arial, Helvetica, sans-serif")
        .style("fill", "blue")
        .text("End")
        .style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
    table_title.append("line")
        .attr("x1", 20)
        .attr("y1", 20)
        .attr("x2", 260)
        .attr("y2", 20)
        .style("stroke", "black")
        .style("stroke-width", "1px")
        .style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
        
    var table_start = s_i.append("g")
        .attr("id", "table_start")
        .attr("transform", transf.tf_table_start)
        .attr("visibility", "visible");
    
    table_start.selectAll("text")
        .data(table_text)
        .enter().append("text")
        .attr("id", function(d) { return "text_" + d.id; })
    	.attr("x", function(d,i) { return (column_start - (d.start.toString().length)); })
    	.attr("y", function(d) { 
    					if(d.pattern != null)
    						return 25;
    					else
    						return 15; })
    	.attr("transform", function(d, i) { 
    						
    						if(d.pattern == null)
    							return "translate(0," +  i * 45 + ")";
    						else
    							return d3.select("#i_e_" + d.id).attr("transform"); 
    						})
        .style("font-size", "16px")
        .style("font-family", "Arial, Helvetica, sans-serif")
        .style("fill", "black")
        .text(function(d) { 
                if(d.pattern == null)
                    return o_s.exons[d.id].start;
                else
                    return o_s.introns[d.id].start; })
        .style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
    
    var table_end = s_i.append("g")
        .attr("id", "table_end")
        .attr("transform", transf.tf_table_end)
        .attr("visibility", "visible");
    
    table_end.selectAll("text")
        .data(table_text)
        .enter().append("text")
        .attr("id", function(d) { return "text_" + d.id; })
        .attr("x", function(d,i) { return (column_end - (d.start.toString().length)); })
    	.attr("y", function(d) { 
    					if(d.pattern != null)
    						return 25;
    					else
    						return 15; })
    	.attr("transform", function(d, i) { 
    						
    						if(d.pattern == null)
    							return "translate(0," +  i * 45 + ")";
    						else
    							return d3.select("#i_e_" + d.id).attr("transform"); 
    						})
        .style("font-size", "16px")
        .style("font-family", "Arial, Helvetica, sans-serif")
        .style("fill", "black")
        .text(function(d) { 
                if(d.pattern == null)
                    return o_s.exons[d.id].end;
                else
                    return o_s.introns[d.id].end; })
        .style("opacity", "0.0")
        .transition()
        .duration(750)
        .style("opacity","1.0");
}


/* PATTERN_EXONS
 * 
 * Definisce un pattern a strisce per differenziare la tipologia
 * degli esoni.
 */                
function pattern_exons(){
    
    defs = d3.select("body").append("svg")
        .append('defs');
    defs.append('defs')
        .append('pattern')
        .attr('id', 'diagonalHatch')
        .attr('patternUnits', 'userSpaceOnUse')
        .attr('width', 4)
        .attr('height', 4)
        .append('path')
        .attr('d', 'M-1,1 l2,-2 M0,4 l4,-4 M3,5 l2,-2')
        .attr('stroke', '#000000')
        .attr('stroke-width', 1.5);
}


/* CHECK_STRUCTURE_ELEMENT
 * regions_info -> vettore che contiene l'id della regione
 *                 selezionata con il mouse
 * c -> coordinate(mouse) della selezione
 * r_e -> contenitore degli esoni
 * 
 * Crea una struttura di esoni e introni in base
 * alle coordinate della selezione. Restituisce una struttura contenente
 * gli array degli esoni e introni trovati.
 */
function check_structure_element(regions_ext, c, r_e){
		
    //elementi che verranno estratti dalla selezione 
    var element = {
    	r_i : [],
    	i_i : [],
    };
    //contenitore degli splice sites da evidenziare
    splice_select = [];
	var s, e;
    
    //il click della selezione è stato fatto sopra un esone
    if(flag_exon == true){
    	//ricerca gli esoni contengono la regione
    	for(re = 0; re < exons_restruct.length; re++)
    		for(ra = 0; ra < exons_restruct[re].regions.length; ra++)
    			if(regions_ext.id == exons_restruct[re].regions[ra])
        			element.r_i.push(exons_restruct[re]);
    	
    	//rimuove i duplicati tra gli esoni trovati
    	element.r_i = remove_duplicate(element.r_i);
    }
        
    //ricerca degli introni
    for(i = 0; i < introns_restruct.length; i++)
    	for(ra = 0; ra < introns_restruct[i].regions.length; ra++){
			if(+regions_ext.id == introns_restruct[i].regions[ra])            
				element.i_i.push(introns_restruct[i]);
        d3.select("#i_e_" + introns_restruct[i].id).remove();
    	}
    element.i_i = remove_duplicate(element.i_i);

    //elementi.i_i è NULL se nella selezione non sono presenti gli introni
    if(element.i_i != null){
		for(rs = 0; rs < element.i_i.length; rs++)
    		r_e.append("line")
				.attr("id", "intron_s")
				.attr("x1", function(d) { return x(element.i_i[rs].start); })
				.attr("y1", 35)
				.attr("x2", function(d) { return x(element.i_i[rs].end); })
				.attr("y2", 35)
				.style("stroke", "black")
				.style("stroke-width", 6);
		//selezione degli splice sites corrispondenti alle coordinate
		for(l = 0; l < element.i_i.length; l++){
			s = element.i_i[l].start;
			sl = element.i_i[l].start - 1;
			e = element.i_i[l].end;
			em = element.i_i[l].end + 1;
			for(h = 0; h < s_s_restruct.length; h++){
				if((s_s_restruct[h].position == s) | (s_s_restruct[h].position == e))
					splice_select.push(s_s_restruct[h]);
				if((s_s_restruct[h].position == sl) | (s_s_restruct[h].position == em))
					splice_select.push(s_s_restruct[h]);
			}
		}
	}
    
    if(element.r_i != null){
    	//elementi selezionati evidenziati sulla struttura genica
    	for(rs = 0; rs < element.r_i.length; rs++)
    		r_e.append("rect")
				.attr("id", "exon_s")
				.attr("x", x(element.r_i[rs].start))
        		.attr("y", 0)
				.attr("width", function() { return x(element.r_i[rs].end) - x(element.r_i[rs].start) - 1; })
				.attr("height", "75")
				.attr("rx", 3)
				.attr("ry", 3)
				.style("fill", function() {	return d3.rgb("#228B22"); });
	
		//selezione degli splice sites corrispondenti alle coordinate
		for(l = 0; l < element.r_i.length; l++){
			s = element.r_i[l].start;
			sl = element.r_i[l].start - 1;
			e = element.r_i[l].end;
			em = element.r_i[l].end + 1;
			for(h = 0; h < s_s_restruct.length; h++){
				if((s_s_restruct[h].position == s) | (s_s_restruct[h].position == e))
					splice_select.push(s_s_restruct[h]);
				if((s_s_restruct[h].position == sl) | (s_s_restruct[h].position == em))
					splice_select.push(s_s_restruct[h]);
			}
		}
	}
	
	splice_select = remove_duplicate(splice_select);
	
	for(l = 0; l < splice_select.length; l++){
		d3.select("#s_s_" + splice_select[l].id)
			.style("stroke-width", "1.5px")
			.style("stroke", d3.rgb("blue").brighter(3));
		d3.select("#up_" + (splice_select[l].id))
            .style("stroke", "black");
        d3.select("#down_" + (splice_select[l].id))
        	.style("stroke", "black");
	}       
	
    return element;   
}

/* MOUSE_POS
 * xm -> coordinata sull'assse X del mouse
 * ym -> coordinata sull'asse Y del mouse
 * 
 * Aggiunge un segnalatore nel punto in cui è avvenuto il click del mouse.
 */
function mouse_pos(xm, ym){
	
	d3.selectAll("#cross_pos").remove();
	
	svg_isoform.append("path")
		.attr("id", "cross_pos")
    	.attr("transform", function(d) { return "translate(" + xm + "," + ym + ")"; })
    	.attr("d", d3.svg.symbol().type("cross"))
    	.style("fill", "yellow");
}

/* DRAW_EXONS
 * box -> contenitore dell'isoforma
 * exons -> struttura dati degli esoni
 * x_scale -> variabile che contiente la funzione per il range e il dominio di
 * 			  visualizzazione
 * 
 * Disegna gli esoni differenziandoli in base al campo "alternative". In base
 * alla posizione del mouse e all'evento connesso ad esso, richiama le funzioni 
 * per la visualizzazione degli elementi selezionati.
 */
function draw_exons(box, exons, x_scale){
	
	//array per gli esoni "conservative"
	var exons_stripe = [];
	//altezza esoni
	var exons_h = 75;
	
	//colori per gli elementi
	var color_exon = function() { return d3.rgb("#228B22"); };
	var color_exon_after = function() { return d3.rgb("#D3D3D3"); };
    var color_intron = function() { return d3.rgb("black"); };
    var color_intron_after = function() { return d3.rgb("#D3D3D3"); };
	
	//vettore di esoni 'conservative'
	for(k = 0; k < exons.length; k++)
	   if(exons[k].alternative == false)
	       exons_stripe.push(exons[k]);
    	  			  	
	//variabile per traslare gli esoni
	var tf = d3.svg.transform()
		.translate(function (d) { return [x_scale(d.start), 0]; });
	
	//contenitore degli esoni 'alternative'
	var rect_exons = box.append("g")
		.attr("id", "exons")
		.attr("transform", "translate(" + margin_isoform.left + "," + margin_isoform.top/2 + ")");
	//aggiunge i blocchi "esoni"
	rect_exons.selectAll("rect")
		.data(exons)
		.enter()
		.append("rect")
		.attr("id", "exon")
		.attr("width", function(d) { return x_scale(d.end) - x_scale(d.start) - 1; })
		.attr("height", "0")
		.attr("rx", 3)
		.attr("ry", 3)
		.style("fill", color_exon)
		.style("opacity", 1.0)
		.attr("transform",tf)
		.on("click", function(d){ 
					   
					   //aggiorna la selezione
					   if(flag_structure == true){
					      d3.selectAll("#exon_s")
					      	.remove();	
					      d3.selectAll("#intron_s")
					      	.remove();				
					   }
					   
					   //selezione sopra esoni 'alternative'	 	   
		               if(d.alternative == true){
		               	  //colora di grigio la struttura per evidenziare la selezione
		                  d3.selectAll("#exon")
						    .style("fill", color_exon_after);
						  d3.selectAll("#intron")
                            .style("stroke", color_intron_after);
                          for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#up_" + s)
                            	.style("stroke", color_intron_after);
                          for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#down_" + s)
                            	.style("stroke", color_intron_after);
                          
                          //ripristina gli splice sites
                          for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#s_s_" + s_s_restruct[s].id)
                            	.style("stroke", color_intron_after)
                            	.style("stroke-width", "1px");
                          									
						  //coordinate della posizione del mouse al momento del "click"
						  var coord_x = x_scale.invert(d3.event.pageX - 25);
						  //sottrae i valori della traslazione
						  var xc = d3.event.pageX - 15;
						  var yc = d3.event.pageY - 60;
						  mouse_pos(xc, yc);
						  
						  //funzioni per gli elementi selezionati
						  var regions = regions_select(coord_x);
						  flag_exon = true;					  
						  info_structure = check_structure_element(regions, coord_x, rect_exons);  	
						  display_info(svg_expande, x_scale, info_structure, rect_exons);
						  sequence_box(box, info_structure);
						      
        			      }
        			    flag_structure = true; })							  		
		.on("mouseover", function() { d3.select(this).style('cursor', 'cell'); })
		.on("mouseout", function() { d3.select(this).style('cursor', 'default'); })
	    .transition()
	    .duration(750)
	    .attr("height", exons_h);
	
	//esoni 'conservated'							 
	var rect_exons_stripe = box.append("g")
        .attr("id", "exons_stripes")
        .attr("transform", "translate(" + margin_isoform.left + "," + margin_isoform.top/2 + ")");
    //aggiunge i blocchi per gli esoni 'conservated'
    rect_exons_stripe.selectAll("rect")
        .data(exons_stripe)
        .enter()
        .append("rect")
        .attr("id", "exon_stripe")
        .attr("width", function(d) { return x_scale(d.end) - x_scale(d.start) - 1; })
        .attr("height", "0")
        .attr("rx", 3)
		.attr("ry", 3)
		//applica la texture a strisce
        .style("fill", 'url(#diagonalHatch)')
        .attr("transform",tf) 
        .on("click", function(d){ 
        				
        				//aggiorna la selezione
        				if(flag_structure == true){
					      d3.selectAll("#exon_s")
					      	.remove();
					      d3.selectAll("#intron_s")
					      	.remove();
					    }
        				
        				//colora di grigio la struttura per evidenziare
        				//la selezione degli elementi
                        d3.selectAll("#exon")
                          .style("fill", color_exon_after);
                        d3.selectAll("#intron")
                            .style("stroke", color_intron_after);
                        for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#up_" + s)
                            	.style("stroke", color_intron_after);
                        for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#down_" + s)
                            	.style("stroke", color_intron_after); 
                        
                        //ripristina gli splice sites    
                        for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#s_s_" + s_s_restruct[s].id)
                            	.style("stroke", color_intron_after)
                            	.style("stroke-width", "1px");
                         
        		        //coordinate della posizione del mouse al momento del "click"       
                        var coord_x = x_scale.invert(d3.event.pageX - 25);
                        var xc = d3.event.pageX - 15;
						var yc = d3.event.pageY - 60;
						mouse_pos(xc, yc);
						
						//funzioni per gli elementi selezionati  
						var regions = regions_select(coord_x);
						flag_exon = true;
                       	info_structure = check_structure_element(regions, coord_x, rect_exons);  
                        display_info_stripe(svg_expande, x_scale, info_structure, rect_exons_stripe);
                        sequence_box(box, info_structure);
                        
						flag_structure = true; })                           
        .on("mouseover", function() { d3.select(this).style('cursor', 'cell'); })
        .on("mouseout", function() { d3.select(this).style('cursor', 'default'); })
        .transition()
        .duration(750)
        .attr("height", exons_h);
          		
	return rect_exons;	
}


/* DRAW_INTRONS
 * box -> contenitore dell'isoforma
 * introns -> struttura dati degli introni
 * x_scale -> variabile che contiente la funzione per il range e il dominio di
 * 			  visualizzazione
 * 
 * Disegna gli introni. In base
 * alla posizione del mouse e all'evento connesso ad esso, richiama le funzioni 
 * per la visualizzazione degli elementi selezionati.
 */
function draw_introns(box, introns, x_scale){
    
    //colori per gli elementi
	var color_exon = function() { return d3.rgb("#228B22"); };
	var color_exon_after = function() { return d3.rgb("#808080"); };
    var color_intron = function() { return d3.rgb("black"); };
    var color_intron_after = function() { return d3.rgb("#808080"); };
    
    //contenitore degli introni
	var line_introns = box.append("g")
		.attr("id", "introns")
		.attr("transform", "translate(" + margin_isoform.left + "," + margin_isoform.top/2 + ")");
		
	line_introns.selectAll("line")
		.data(introns)
		.enter().append("line")
		.attr("id", "intron")
		.attr("x1", function(d) { return x(d.start); })
		.attr("y1", 35)
		.attr("x2", function(d) { return x(d.start); })
		.attr("y2", 35)
		.style("stroke", color_intron)
		.style("stroke-width", 6)
		.on("click", function(d){
			
						if(flag_structure == true){
					      d3.selectAll("#exon_s")
					      	.remove();	
					      d3.selectAll("#intron_s")
					      	.remove();				
					   }
					   	
					   	//colora di grigio la struttura per evidenziare
					   	//la selezione degli elementi 	   
		                d3.selectAll("#exon")
						    .style("fill", color_exon_after);
						d3.selectAll("#intron")
                            .style("stroke", color_intron_after);
                        for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#up_" + s)
                            	.style("stroke", color_intron_after);
                        for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#down_" + s)
                            	.style("stroke", color_intron_after);
                          
                        for(s = 0; s < s_s_restruct.length; s++)
                          	d3.select("#s_s_" + s_s_restruct[s].id)
                            	.style("stroke", color_intron_after)
                            	.style("stroke-width", "1px");
                                                   
                        //coordinate della posizione del mouse al momento del "click"
						var coord_x = x_scale.invert(d3.event.pageX - 25);
						var xc = d3.event.pageX - 15;
						var yc = d3.event.pageY - 60;
						mouse_pos(xc, yc);
						  
						//funzioni per gli elementi selezionati
						var regions = regions_select(coord_x);		
						flag_exon = false;			  
						info_structure = check_structure_element(regions, coord_x, line_introns);  	
						display_info(svg_expande, x_scale, info_structure, line_introns, x_scale);
						sequence_box(box, info_structure);
						
						})
		.on("mouseover", function() { d3.select(this).style('cursor', 'cell'); })
		.on("mouseout", function() { d3.select(this).style('cursor', 'default'); })
		.transition()
		.delay(750)
		.duration(750)
		.attr("x2", function(d) { return x(d.end); });
			
	return line_introns;
}


/* CLONE_SVG_ELEMENT (DEPRECATED)
 * svg -> variabile che contiene l'elemento "svg"
 * obj -> oggetto da clonare
 * 
 * Clona l'oggetto contenuto in "obj" e lo aggiunge alla finestra di 
 * visualizzazione contenuta nella variabile "svg".
 * Il contenitore "g" del "segnale alto" della tipologia degli splice sites 
 * viene clonato e riutilizzato per aggiungere un "segnale basso".
 * Il tag <use> in Safari e Chrome non viene renderizzato istantaneamente.
 */
function clone_svg_element(svg, obj) {
	
	var triangle_down = svg.append("use")
    	.attr("xlink:xlink:href","#" + obj.attr("id"));
    return triangle_down;
}


/* DRAW_SPLICE_SITES
 * box -> variabile che contiente l'elemento "svg"
 * s_s -> struttura dati degli splice sites
 * x_scale -> variabile che contiente la funzione per il range e il dominio di
 * 			  visualizzazione
 * 
 * Disegna gli splice sites e i segnali che ne indicano la tipologia.
 */
function draw_splice_sites(box, s_s, x_scale){
		
	var color_s_s = function() { return d3.rgb("black"); };
		
	//variabile per i simboli della tipologia 
	//degli splice sites
	var s_sy = d3.svg.symbol()
		.type('triangle-up')
		.size(20);
					
	//contenitore degli splice sites
	var splice_sites = box.append("g")
		.attr("id", "splice_sites")
		.attr("transform", "translate(" + margin_isoform.left + "," + margin_isoform.top/2 + ")");
	
	//aggiunge le linee che rappresentano gli splice sites	
	splice_sites.selectAll("line")
		.data(s_s)
		.enter().append("line")
		.attr("id", function(d) { return "s_s_" + d.id; })
		.attr("x1", function(d) { if(d.position != null) 
									return x_scale(d.position); })
		.attr("y1", -30)
		.attr("x2", function(d) { if(d.position != null)
									return x_scale(d.position); })
		.attr("y2", 110)
		.style("opacity", "0.0")
		.style("stroke", color_s_s)
		.style("strole-width", "2px")
		.style("stroke-dasharray", function(d) { 
									  //differenziazione degli splice sites
		                              if ((d.type == "init") | (d.type == "term"))
									       return 4;
									  else
										   if(d.type != "unknow")
										      return 0; })
	    .transition()
	    .delay(1500)
	    .duration(750)
	    .style("opacity", "1.0");
	    									  
	//segnale alto tipologia splice sites		
	var triangle_up = box.append("g")
		.attr("id", "triangle_up")
		.attr("transform", "translate(" + margin_isoform.left + "," + margin_isoform.top/2 + ")");
										
	triangle_up.selectAll("path")
		.data(s_s)
		.enter().append("path")
		.attr("id", function(d, i) { return "up_" + d.id; })
		.attr("d", s_sy)
		.attr("fill", "none")
		.attr("stroke","black")
		.attr("stroke-width", "1px")
		.attr("visibility", function(d) { 
								//se lo splice site è 'init' o 'term' non deve
								//aver un segnale di tipologia
								if((d.type == 'init') | (d.type == 'term'))
									return "hidden";
								else
									return "visible";})
		.style("opacity", "0.0")
		.attr("transform", function (d) {
							  //ruota il segnale in base alla tipologia
		                      if(d.type == 3)
							     return "translate(" + (x_scale(d.position) - 3) + ",-27)" + "rotate(-90)";
							  else
							  	 if(d.type == 5)
								 	return "translate(" + (x_scale(d.position) + 3) + ",-27)" + "rotate(90)"; })
	    .transition()
        .delay(1500)
        .duration(750)
        .style("opacity", "1.0");
    
    //contenitore segnale basso degli splice sites
    var triangle_down = box.append("g")
		.attr("id", "triangle_down")
		.attr("transform", "translate(" + margin_isoform.left + "," + margin_isoform.top/2 + ")");
											
	triangle_down.selectAll("path")
		.data(s_s)
		.enter().append("path")
		.attr("id", function(d, i) { return "down_" + d.id; })
		.attr("d", s_sy)
		.attr("fill", "none")
		.attr("stroke","black")
		.attr("stroke-width", "1px")
		.style("opacity", "0.0")
		.attr("visibility", function(d) { 
								if((d.type == 'init') | (d.type == 'term'))
									return "hidden";
								else
									return "visible";})
		.attr("transform", function (d) {
		                      if(d.type == 3)
							     return "translate(" + (x_scale(d.position) - 3) + ", 106)" + "rotate(-90)";
							  else
							     if(d.type == 5)
								    return "translate(" + (x_scale(d.position) + 3) + ", 106)" + "rotate(90)"; })
	    .transition()
        .delay(1500)
        .duration(750)
        .style("opacity", "1.0");
   		
	return splice_sites;
}


/* SEQUENCE_BOX
 * s_box -> contenitore della struttura genica
 * seq_info -> array contenente gli elementi di cui visualizzare 
 * 			   la sequenza
 * 
 * Visualizza le sequenze nucleotidiche degli elementi selezionati.
 */
function sequence_box(s_box, seq_info){
	
	//colori titolo e sequenze
	var color_title = function() { return d3.rgb("blue"); };
	var color_sequence = function() { return d3.rgb("black"); };
	
	//oggetto delle posizioni in base al numero di sequenze 
	//da visualizzare
	var position = {
		y_pos : 190,
		x_pos_ex : 150,
		x_pos_in : 150
	};
    
    if(flag_sequence == false){
    	s_box.append("text")
        	.attr("id", "title_sequence")
        	.attr("x", 0)
        	.attr("y", 30)
        	.style("font-family", "Arial, Helvetica, sans-serif")
        	.style("font-size", "20px")
        	.style("fill", color_title)
        	.text("Nucleic sequence:")
        	.attr("transform", "translate(" + margin_isoform.left + "," + position.y_pos + ")")
        	.style("opacity", "0.0")
        	.transition()
        	.duration(750)
        	.style("opacity","1.0");
        flag_sequence = true;
    }
    	
    //offset tra sequenze di esoni e introni in base alla presenza degli stessi
    if(seq_info.r_i != null)   	
		off_set_ex = seq_info.r_i.length * position.x_pos_ex;
	if(seq_info.i_i != null)
		var off_set_in = seq_info.i_i.length * position.x_pos_in;
	
	//box per le sequenze degli esoni
	var sequence_ex = s_box.append("g")
		.attr("id", "sequence_ex")
		.attr("transform", "translate(" + (margin_isoform.left * 20) + "," + position.y_pos + ")");
    
    //box per le sequenze degli introni
    var sequence_in = s_box.append("g")
        .attr("id", "sequence_in")
        .attr("transform", "translate(" + (off_set_ex + (margin_isoform.left * 20)) + "," + position.y_pos + ")");
        
    //sequenze esoni
    sequence_ex.selectAll("text")
    	.data(seq_info.r_i)
    	.enter().append("text")
    	.attr("id", function(d) { return "sequence_ex_" + d.id; })
        .attr("x", function (d, i) { 
        			//la sequenza da visualizza viene costruita concatenando le prime e le ultime
        			//quattro lettere ed inserendo dei caratteri di continuità nel mezzo.
        			//Viene utilizzata per calcolare la posizione del testo.
        			var seq = '';
        			var li = '- - - - -';
        			seq = seq.concat(d.sequence.slice(0,4).toUpperCase(), li,
        							 d.sequence.slice(d.sequence.length - 4,d.sequence.length).toUpperCase());
        			//calcolo della lunghezza della stringa in base al font
        			var canvas = document.createElement('canvas');
					var ctx = canvas.getContext("2d");
					ctx.font = "15px Arial";        
					var width_seq = ctx.measureText(seq).width;
        			return (i * width_seq); })
        .attr("y", 30)
        .style("font-size", "12px")
        .style("font-family", "Arial, Helvetica, sans-serif")
        .style("fill", color_sequence)
        .style("opacity", "0.0")
        .text(function(d) { 
        		//la sequenza da visualizza viene costruita concatenando le prime e le ultime
        		//quattro lettere ed inserendo dei caratteri di continuità nel mezzo
        		var seq = '';
        		var li = '- - - - -';
        		seq = seq.concat(d.sequence.slice(0,4).toUpperCase(), li,
        					     d.sequence.slice(d.sequence.length - 4,d.sequence.length).toUpperCase());
        		return seq; })
        .transition()
        .duration(750)
        .style("opacity","1.0");
    
    //sequenze introni
    //solo se gli introni appartengono alla selezione    
    if(seq_info.i_i != null)
        sequence_in.selectAll("text")
            .data(seq_info.i_i)
            .enter().append("text")
            .attr("id", function(d) { return "sequence_in_" + d.id; })
            .attr("x", function (d, i) {
            			
            			//la sequenza da visualizza viene costruita concatenando le prime e le ultime
        				//quattro lettere ed inserendo dei caratteri di continuità nel mezzo.
        				//Viene utilizzata per calcolare la posizione del testo.
            			var seq_in = d.prefix + d.suffix;
            			var seq = '';
        				var li = '- - - - -';
        				seq = seq.concat(seq_in.slice(0,4).toUpperCase(), li,
        								 seq_in.slice(seq_in.length - 4, seq_in.length).toUpperCase());
            			var canvas = document.createElement('canvas');
						var ctx = canvas.getContext("2d");
						ctx.font = "18px Arial";        
						var width_seq = ctx.measureText(seq).width;
        				return (i * width_seq); })
            .attr("y", 30)
            .style("font-size", "12px")
            .style("font-family", "Arial, Helvetica, sans-serif")
            .style("fill", color_sequence)
            .style("opacity", "0.0")
            .text(function(d) {
            		//la sequenza da visualizza viene costruita concatenando le prime e le ultime
        			//quattro lettere ed inserendo dei caratteri di continuità nel mezzo.
            		var seq_in = d.prefix + d.suffix;
            		var seq = '';
        			var li = '- - - - -';
        			seq = seq.concat(seq_in.slice(0,4).toUpperCase(), li,
        							 seq_in.slice(seq_in.length - 4, seq_in.length).toUpperCase()); 
            		return seq; })
            .transition()
        	.duration(750)
        	.style("opacity","1.0");        
}


/* SCALING_REGIONS
 * r -> regioni
 * 
 * Modifica le regioni in base alla loro dimensione (size = end - start). Aumenta
 * quelle minori di 50 e diminuisce quelle maggiori di 1500
 */
function scaling_regions(r){
	
	//calcolo delle dimensioni delle regioni
	for(i = 0; i < r.length - 1; i++){
		size_regions = r[i].end - r[i].start;
		
		//regioni troppo piccole (< 50 pixel)
		if(size_regions < 50){
			size_regions_scaled = size_regions * (80 / size_regions);
			r[i].end = r[i].end + size_regions_scaled;
			r[i + 1].start = r[i].end;
		}
		//regioni troppo grandi (> 1500 pixel)
		if(size_regions > 1500){
			size_regions_scaled = size_regions * (800 / size_regions);
			r[i].end = r[i].end - size_regions_scaled;
			r[i + 1].start = r[i].end;
		}	
	}
    return r;
}


/* CHANGE_GENE 
 * gene -> nome file JSON contenente la struttura dei dati
 * 
 * Permette di cambiare gene, rimuovendo la struttura disegnata e 
 * richiamando nuovamente la funzione "init" per disegnare la nuova
 * struttura.
 */
function change_gene(gene){
    
    //durata animazioni
    var d = 450;
    
    //rimozione di tutti i box SVG
    var g = d3.select("#isoform").selectAll("g");
    g.remove();
        
    //pulisce la finestra degli elementi selezionati
    remove_element_expande_box();
    
    //aggiorna il file json da cui estrarre i dati
    default_structure = gene;
    
    //reinizializza la struttura
    init();
    zoom_isoform.translate([0, 0]).scale(1);
    svg_isoform.transition()
    	.duration(d)
        .attr("transform", "translate(" + zoomListener.translate() + ")scale(" + zoomListener.scale() + ")");  
    flag_zoom = false;
    svg_isoform.on("mousedown.zoom", null);
	svg_isoform.on("mousemove.zoom", null);
	svg_isoform.on("dblclick.zoom", null);
	svg_isoform.on("touchstart.zoom", null);
	svg_isoform.on("wheel.zoom", null);
	svg_isoform.on("mousewheel.zoom", null);
	svg_isoform.on("MozMousePixelScroll.zoom", null); 
}


/* NAVIGATION_BAR
 * 
 * Modifica la navbar creata nel file index.html aggiungendo
 * le informazioni relative al gene selezionato.
 */
function navigation_bar(){
	
	var d = 450;
	
	//nome del gene
	var h_g = d3.select("#home_gene");
	h_g.text(string_gene + " gene structure");
	
	h_g.on("click", function(){ 
						//assegna al nome del gene le stesse funzioni del pulsante reset
						remove_element_expande_box();
						//riporta la struttura genica alle dimensioni originali
        				zoom_isoform.translate([0, 0]).scale(1);
        				svg_isoform.transition()
        					.duration(d)
        					.attr("transform", "translate(" + zoom_isoform.translate() + ")scale(" + zoom_isoform.scale() + ")");
						});
	
	//legge il file JSON di configurazione. Contiene la lista
	//dei file JSON
	d3.json("Json_file/config.json", function(error, list) {
		
		//aggiunge la lista selezionabile dei file JSON
		var dp_s = d3.select("#select_gene");
		dp_s.selectAll("li")
			.data(list.gene_structures)
			.enter().append("li")
			.append("a")
				.attr("href", "#")
	   			.text(function(d) { return d.name; })
	   			.on("click", function(d) { change_gene(d.name); });
	});
}

/* SETUP_INTERFACE
 * 
 * Inizializza le finestre di visualizzazione e chiama la funzione "init".
 */
function setup_interface(){
      
    //texture esoni alternative  
    pattern_exons();
    
    //oggetto per la posizione della finestra della struttura
    var pos_box = {
    	pos: "absolute",
    	left : "10px",
    	right : "10px",
    	top : "60px",
    	bottom : "10px"
    };
    svg_isoform = set_svg("isoform", width - width_isoform, height_isoform, pos_box); 
        
    init();   
    
    svg_expande = svg_expande_box();  
    
    legend_box();  
    buttons();                       
}


/* ORIGINAL_STRUCTURE
 * s -> struttura
 * type_structure -> tipologia della struttura (esone, introni o splice sites)
 * 
 * Ricalcola le strutture utilizzando i valori originali delle regioni.
 */
function original_structure(s, type_structure){
	
	var st;
	
	switch(type_structure){
		case 'exon':
		{
			st = exons_structure(exons, s, boundaries);
			break;	
		}
		case 'intron':
		{
			st = introns_structure(introns, s, boundaries);
			break;
		}
		case 'splice':
		{
			st = splice_sites_structure(s, boundaries);
		}
	}
	
	return st;
}

/* COPY_REGIONS
 * s -> struttura delle regioni da copiare
 * 
 * Copia il vettore delle regioni che poi sara modificato
 * per scalare le dimensioni degli elementi
 */
function copy_regions(s){
    
    var copy_reg = [];
    for(t = 0; t < s.length; t++)
        copy_reg.push({
            "start" : s[t].start,
            "end" : s[t].end,
            "sequence" : s[t].sequence,
            "type" : s[t].type,
            "alternative" : s[t].alternative,
            "coverage" : s[t].coverage,
            "last" : s[t].last,
            "id" : s[t].id    
        });
    
    return copy_reg;    
}

/* COPY_INFO_GENE
 * s -> struttura delle informazioni da copiare
 * 
 * Copia gli oggetti relativi alle informazione
 * sul gene.
 */
function copy_info_gene(s){
    
    var copy_info;
    copy_reg = {
    	"sequence_id" : s.sequence_id,
        "program_version" : s.program_version,
        "file_format_version" : s.file_format_version,
        "gene" : s.gene    
    };
    
    return copy_reg;    
}

/* FILE_INFORMATION
 * 
 * Riporta nella navbar le informazioni sul file JSON.
 */
function file_information(){
	
	var dp_i = d3.select("#info_gene");
	dp_i.selectAll("li").remove();
	dp_i.append("li")
		.style("font-size", "12px")
		.text(function() { return "sequence_id: " + original_info.sequence_id; });
	dp_i.append("li")
		.style("font-size", "12px")
	   	.text(function() { return "file_format_version: " + original_info.file_format_version; });
	dp_i.append("li")
		.style("font-size", "12px")
	   	.text(function() { return "program_version: " + original_info.program_version; });
}

/* INIT
 * 
 * Inizializza tutte le funzione per disegnare la struttura. 
 * Carica i dati dal file json relativo al gene selezionato.
 * Di default carica "ATP6AP1example2.json"
 */
function init(){
	
    var path_file = "Json_file/";
    //carica i dati contenuti nel file json e richiama le funzioni per disegnare la struttura
    //dell'isoforma
    d3.json(path_file.concat(default_structure), function(error, atp) {
	
	   if(error != null){
	   	  console.log(error);
	   	  console.log(error.response);
	   	  var error_string = "";
	   	  error_string = error_string.concat(error.responseURL, " ", error.statusText);
	   	  window.alert(error_string);
	   }
	   	  
	   isoform = atp[0];
	   
	   original_info = copy_info_gene(isoform);
	   
	   //copia dell'array originale delle regioni
	   original_regions = copy_regions(isoform.regions);
	   //regioni
	   x = isoform_range(isoform.regions);
	   regions = scaling_regions(isoform.regions);
	   
	   //estrae il nome del gene
	   string_gene = original_info.gene;
	
	   //navbar
	   navigation_bar();	   
	   file_information();
	   
	   //boundaries
	   boundaries = isoform.boundaries;

	   //esoni
	   exons = isoform.exons;

	   //introni
	   introns = isoform.introns;
	
	   //esoni, introni e boundaries ricostruiti
	   exons_restruct = exons_structure(exons, regions, boundaries);
	   introns_restruct = introns_structure(introns, regions, boundaries);
	   s_s_restruct = splice_site_structure(boundaries, regions);
	  
	   //disegna la struttura
	   line_i = draw_introns(svg_isoform, introns_restruct, x);
	   rect = draw_exons(svg_isoform, exons_restruct, x);
	   s_s = draw_splice_sites(svg_isoform, s_s_restruct, x);	  	
    });
}	