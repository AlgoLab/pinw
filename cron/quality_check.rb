#!/usr/bin/env ruby

require 'optparse'
options = {}
OptionParser.new do |opts|
  opts.banner = "Utilizzo dello script: ruby progetto.rb [options]"
  opts.on( "-f", "--filename FILENAME", String,
           "Nome del file di input" ) do |f|
  			options['filename'] = f 
  end
  opts.on( "-q", "--quality QUALITY", Integer,
           "Numero che indica la qualita minima di ogni base" ) do |q|
  			options['quality'] = q 
  end
  opts.on( "-o", "--output [OUTFILENAME]", String,
           "Nome del file prodotto in output" ) do |o|
  			options['output_filename'] = o
  end
  opts.on("-t", "--trim","Questo parametro specifica se bisogna effettuare il trim dei read") { |t|  options['trim'] = t }
  opts.on("-m", "--min-read-length [MRL]",Integer,"Specifica la lunghezza minima del read per un trim valido") { |m|  options['mrl'] = m }
end.parse!

# Filename e qualità sono parametri obbligatori, se non sono presenti viene arrestato lo script
begin
    raise "Nome del file obbligatorio"       if options['filename'].nil? 
    raise "Livello di qualità obbligatorio"  if options['quality'].nil? 
rescue Exception => ex
    puts "#{ex.message()}. Digitare -h per visualizzare i parametri dello script."
    exit(1)
end

FASTQ_FILENAME = options['filename']
Q_INPUT = options['quality'] 
TRIM = options['trim']
MIN_READ_LENGHT = options['mrl']

is_line_ok = true
index_lines_ok = Array.new	# Array contenente gli indici delle righe che vanno bene
index_lines_to_trim  = Hash.new  # Hash che mappa gli indici delle righe con l'ultima posizione dell'indice che va bene 

def trim(quality_string)
	index_base_begin = 0 
	index_base_end   = 0
	quality_string.each_char.with_index do |c,i|				 
		if c.ord-33 < Q_INPUT
		 	index_base_begin = i-1
		end
		break if index_base_begin != 0
	end
	#Dato che possono essere tagliate anche le parti iniziali utilizzo la funzione reverse per controllare la qualita
	#togliendo il carattere new line per evitare problemi con il codice ascii
	quality_string = quality_string.reverse!.sub("\n","")
	quality_string.each_char.with_index do |c,i|
		if c.ord-33 < Q_INPUT
		 	index_base_end = i-1
		end
		break if index_base_end != 0
	end
	if index_base_begin >= index_base_end
		# +1 perche ruby è 0 based, ritorno begin cioè effettuo il trim partendo da inizio stringa
		return index_base_begin+1, "begin"
	else	
		# +1 perche ruby è 0 based, ritorno begin cioè effettuo il trim partendo dalla fine della stringa
		return index_base_end+1, "end"
	end
end


File.open(FASTQ_FILENAME, "r") do |fastq_file|
	fastq_file.each_with_index do | line , i | 
		index_base_ok = 0	#Contiene l'indice dell'ultima qualita che supera la qualita minima
		is_line_ok = true
		if (i+1)%4 == 0 	#La qualita si trova ogni 4 righe  (+1 dato che ruby è 0-based)	
			
			if TRIM 
				index_base_ok,begin_or_end = trim(line)
				if index_base_ok >= MIN_READ_LENGHT
					index_lines_to_trim[i+1-2] = index_base_ok.to_i, begin_or_end
					index_lines_to_trim[i+1]   = index_base_ok.to_i, begin_or_end
					range = ((i+1-4)+1..(i+1)) # Range degli indici delle righe che vanno bene
					range.each { |e| index_lines_ok.push(e) }  # Salvo ogni singolo indice in un array 
				end
			
			else 
				line.each_char.with_index do |c,i|
					next if c.ord == 10  #Salto il newline \n
					is_line_ok = false  if c.ord-33 < Q_INPUT
					break 			    if c.ord-33 < Q_INPUT
				end
				if is_line_ok == true
					range = ((i+1-4)+1..(i+1))	# Range degli indici delle righe che vanno bene
					range.each { |e| index_lines_ok.push(e) } # Salvo ogni singolo indice in un array 
				end
			end		
		else
			next
		end
	end
end

#Se non è specificato un nome del file di output, di default sarà output-NOME_DEL_FILE_DI_INPUT
OUTFILENAME = options['output_filename'].nil?  ?  "output-#{FASTQ_FILENAME}"  :  options['output_filename']

out = File.open(OUTFILENAME, 'w')
File.open(FASTQ_FILENAME, "r") do |f|
  f.each_with_index do |line,i|
	if index_lines_ok.include? i+1 #Controllo se l'indice della riga corrente è presente nell'array di quelle che vanno bene
		if TRIM and (index_lines_to_trim.include? i+1 )
			split = index_lines_to_trim[i+1][0] # Split = L'indice in cui viene effetuato il trim
			line = line[0,split] + "\n" 			     if index_lines_to_trim[i+1][1] == "begin"
			line= line[line.length-split-1,line.length]  if index_lines_to_trim[i+1][1] == "end"
		end
		out.write(line) 
	end
  end
end
