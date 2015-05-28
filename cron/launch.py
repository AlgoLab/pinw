#!/usr/bin/env python3

import json
import os
import subprocess

# leggere file cfg  (JSON)
# avviare pintron con quei parametri (gestire problemi)
# i parametri sono:
#   - working dir
#   - use callback
#   - callback url
#   - timeout
# parametri di pitron:
#   - vedi sotto
# mettere da qualche parte il pid dello script e quello di pintron cos da killarli se serve

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
#        --ngs (se est e fastq metto ngs)

def create_json(path, success):
    '''create json output'''
    data = {}
    if success: 
        try:
            with open(path + '/output.txt') as out:
                output = out.read()
            output = json.loads(output)
            data['pintron-output'] = output
            # rielaborare il file
        except:
            success = False
            
    data['success'] = success
    with open('job-result.json', 'w') as outfile:
        json.dump(data, outfile, sort_keys=True, indent=4)

def notify(parameters):
    '''send notification to pinw'''
    use_callback = parameters['use_callback']
    callback_url = parameters['callback_url']
    pass

def prepare_result(path, output):
    '''checks exit code'''
    if output == 0:
        create_json(path, True)
    elif output == -1:
        create_json(path, False)


def run_pintron(path, parameters):
    '''run pintron'''
    pintron_path = parameters['pintron_path'] + "pintron"
    bin_dir = "--bin-dir=" + parameters['pintron_path']
    genomic = "--genomic=" + path + "/genomics.fasta"
    #est = "--EST=" + path + "/" + parameters['est']
    # test version work only with one file
    # PIntron NGS option not yet implemented
    est = "--EST=" + path + "/" + "reads/reads-upload-0"
    organism = "--organism=" + parameters['organism']
    gene = "--gene=" + parameters['gene_name']
    output = "--output=" + path + "/output.txt"
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

    try:
        exit_code = subprocess.call([pintron_path, 
                          bin_dir, 
                          genomic, 
                          est,
                          organism,
                          gene,
                          output], timeout=timeout)
    except subprocess.TimeoutExpired:
        exit_code = -1

    print("exit code:" + str(exit_code))
    return exit_code

def get_parameters(path):
    '''get parameters from json configurazion file'''
    parameters = None
    with open(path + '/job-params.json') as p:
        parameters = p.read()
    parameters = json.loads(parameters)
    return parameters

def check_folder(path):
    '''remove old output file'''
    if os.path.isfile(path + '/output.txt'):
        os.remove(path + '/output.txt')
    if os.path.isfile(path + '/job-result.json'):
        os.remove(path + '/job-result.json')

def main():
    path = os.path.dirname(os.path.abspath(__file__))
    check_folder(path)
    parameters = get_parameters(path)
    output = run_pintron(path, parameters)
    prepare_result(path, output)
    notify(parameters)

if __name__ == '__main__':
    main()