#!/usr/bin/env python3

import json
import os
from subprocess import call

# leggere file cfg  (JSON)
# avviare pintron con quei parametri (gestire problemi)
# i parametri sono:
#   - working dir
#   - use callback
#   - callback url
#   - timeout
# parametri di pitron:
#   - vedi sotto

# pintron crea il json -> lo wrappiamo e ci mettiamo le informazioni aggiunte dal python

# /home/pintron/bin/pintron                               
#        --bin-dir=/home/pintron/bin  ****                    
#        --genomic=/home/pintron/doc/example/genomic.txt  ****
#        --EST=/home/pintron/doc/example/ests.txt     ****    
#        --organism=human   ****                                 
#        --gene=TP53        ****                               
#        --output=pintron-full-output.json                
#        --gtf=pintron-cds-annotated-isoforms.gtf         
#        --extended-gtf=pintron-all-isoforms.gtf          
#        --logfile=pintron-pipeline-log.txt               
#        --general-logfile=pintron-log.txt

def notify():
    pass

def prepare_result(output):
    return None

def run_pintron(parameters):
    '''run pintron'''
    path = os.path.dirname(os.path.abspath(__file__))
    pintron_path = parameters['pintron_path'] + "pintron"
    bin_dir = "--bin-dir=" + parameters['pintron_path']
    genomic = "--genomic=" + path + "/genomics.fasta"
    est = "--EST=" + parameters['est']
    organism = "--organism=" + parameters['organism']
    gene = "--gene=" + parameters['gene']
    output = "--output=" + parameters['output']
    min_read_length = "--min-read-length=" + str(parameters['min_read_length'])

    

    timeout = int(parameters['timeout'])

    print("Calling pintron with the following parameters:\n")
    print(pintron_path)
    print("\t" + bin_dir)
    print("\t" + genomic)
    print("\t" + est)
    print("\t" + organism)
    print("\t" + gene)
    print("\t" + min_read_length)
    print("\t" + output)
    print("\nSelected timeout: " + str(timeout))
    print()

    exit_code = call([pintron_path, 
                      bin_dir, 
                      genomic, 
                      est,
                      organism,
                      gene,
                      output], timeout=timeout)
    return exit_code

def get_parameters():
    '''get parameters from json configurazion file'''
    parameters = None
    path = os.path.dirname(os.path.abspath(__file__))
    with open(path + '/job-params.json') as p:
        parameters = p.read()
    parameters = json.loads(parameters)
    return parameters

def main():
    parameters = get_parameters()
    output = run_pintron(parameters)
    prepare_result(output)
    notify()

if __name__ == '__main__':
    main()