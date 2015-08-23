#!/usr/bin/env python3

import os, json

def convert_json(path, output_file, genomics_file):
    # read output file
    output_file = path + output_file
    output = None
    with open(output_file, 'r') as fp:
        output = json.load(fp)

    # read output genomics
    genomics_file = path + genomics_file
    genomics = ''
    with open(genomics_file, 'r') as fp:
        for line in fp:
            if not line.startswith('>'):
                # remove '\n'
                line = line[:-1]
                genomics += line
    
    introns = output['introns']
    isoforms = output['isoforms']
    
    #visualization json
    viz = {}
    
    # FASTA header del file della genomica (senza '>')
    viz["sequence_id"] = output['genome']['sequence_id']    

    # versione della pipeline che ha prodotto il JSON
    viz["program_version"] = output['program_version']                                
    
    # versione dello schema JSON  
    viz["file_format_version"] = output['file_format_version'] 
    
    # array delle regioni
    viz["regions"] = [] 

    # array dei boundaries                                                        
    viz["boundaries"] = []  

    # array degli esoni         
    viz["exons"] = []   

    # array degli introni           
    viz["introns"] = []         

    # array delle isoforme       
    viz["isoforms"] = []                

    starts = []
    ends = []

    for isoform in isoforms:

        # search for exons start and end
        exons = isoforms[isoform]['exons']
        # foreach exon in this isoform
        for exon in exons:
            starts.append(int(exon['relative_start']))
            ends.append(int(exon['relative_end']))

        # search for introns start and end
        isoform_introns = isoforms[isoform]['introns']
        # foreach intron in this isoform 
        for isoform_intron in isoform_introns:
            # those are only keys ()
            starts.append(int(introns[str(isoform_intron)]['relative_start']))
            ends.append(int(introns[str(isoform_intron)]['relative_end']))

    # now sort everythings
    lcoordinate = sorted(list(set(ends)))
    rcoordinate = sorted(list(set(starts)))

    print('##### LCOORD #####')
    print(lcoordinate)

    print('##### RCOORD #####')
    print(rcoordinate)

    starts = []
    stops = []
    stop = None

    # create regions
    for start in lcoordinate:
        if stop and start <= stop:
            continue
        stops.append(start)
        stop = [x for x in rcoordinate if x > start]
        if (stop):
            stop = min(stop)
            starts.append(stop)

    print('\n##### starts #####')
    print(starts)
    print('##### stops #####')
    print(stops[1:])

    # regions start-stop
    region_id = 0
    for start, stop in zip(starts, stops[1:]):
        region = {}
        region['start'] = start
        # the correct key is end, not start!
        region['end'] = stop
        region['id'] = region_id
        region['last'] = False
        region['sequence'] = genomics[start-1:stop-1]
        # -1!!!! pintron output is 1-based
        region['coverage'] = 100
        # (just to viz the rectangles)
        viz['regions'].append(region)

        region_id += 1

    # set last=True for last region
    last_region_id = region_id - 1
    for region in viz['regions']:
        if region['id'] == last_region_id:
            region['last'] = True


    #boundaries rcoordinate-lcoordinate
    boundary = {}
    boundary['first'] = -1
    boundary['lcoordinate'] = 'unknown'
    boundary['rcoordinate'] = stops[0]
    boundary['type'] = 'unknown'
    viz['boundaries'].append(boundary)

    boundary_first = 0
    for lcoordinate, rcoordinate in zip(stops, starts):
        boundary = {}
        boundary['first'] = boundary_first
        boundary['rcoordinate'] = rcoordinate
        boundary['lcoordinate'] = lcoordinate
        if boundary_first == (last_region_id):
            boundary['type'] = 'term'
        elif boundary_first == 0:
            boundary['type'] = 'init'
        viz['boundaries'].append(boundary)
        boundary_first += 1


    # introns

    # foreach intron in pintron json
    for intron in introns:
        # prepare intron object 
        intron = introns[intron]
        viz_intron = {}

        # retrieve left boundary
        intron_relative_start = intron['relative_start']
        for region in viz['regions']:
            if intron_relative_start == region['start']:
                left_boundary = region['id']
                break
        viz_intron['left_boundary'] = left_boundary

        # retrieve right boundary
        intron_relative_end = intron['relative_end']
        for region in viz['regions']:
            if intron_relative_end == region['end']:
                right_boundary = region['id']
                break
        viz_intron['right_boundary'] = right_boundary

        # retrieve prefix and suffix
        viz_intron['prefix'] = intron['prefix']
        viz_intron['suffix'] = intron['suffix']
        viz['introns'].append(viz_intron)


    # intron - exon number

    # foreach region
    for region in viz['regions']:
        region['intron number'] = 0
        region['exon number'] = 0

        # foreach intron in pintron json
        for intron in introns:
            intron = introns[intron]
            # check if intron 
            if int(intron['relative_start'] <= int(region['start'])) and \
                int(intron['relative_end'] >= int(region['end'])):
                region['intron number'] += 1

        # foreach isoform in pintron json
        for isoform in isoforms:
            exons = isoforms[isoform]['exons']
            # foreach exon in this isoform
            for exon in exons:
                if int(exon['relative_start'] <= int(region['start'])) and \
                    int(exon['relative_end'] >= int(region['end'])):
                    region['exon number'] += 1


    # region type

    # alternative? check may be broken!!!

    # foreach region
    for region in viz['regions']:
        # coding if exon number > 0
        if region['exon number'] > 0:
            # the correct key is codifying not coding
            region['type'] = 'codifying'
            region['alternative?'] = False
            # alternative if exon number < isoforms
            if int(region['exon number']) < len(isoforms):
                region['alternative?'] = True
        elif region['intron number'] > 0:
            region['type'] = 'intron'
        else:
            region['type'] = 'unknown'

    # exons

    # foreach isoform in pintron json
    viz_exons = []
    for isoform in isoforms:
        exons = isoforms[isoform]['exons']
        # foreach exon in this isoform
        for exon in exons:
            viz_exon = {}

            # retrieve left boundary
            exon_relative_start = exon['relative_start']
            left_boundary = -1
            for region in viz['regions']:
                if exon_relative_start == region['start']:
                    left_boundary = region['id']
                    break
            viz_exon['left_boundary'] = left_boundary

            # retrieve right boundary
            exon_relative_end = exon['relative_end']
            right_boundary = -1
            for region in viz['regions']:
                if exon_relative_end == region['end']:
                    right_boundary = region['id']
                    break
            viz_exon['right_boundary'] = right_boundary
            viz_exon['annotated'] = False

            if left_boundary == -1 or right_boundary == -1:
                break

            viz_exons.append(viz_exon)

    # remove duplicated exons
    viz["exons"] = [dict(y) for y in set(tuple(x.items()) for x in viz_exons)]


    # check regions type
    for boundary in viz["boundaries"][:-1]:
        print(boundary)
        print('-')
        boundary_id = boundary['first']

        if boundary_id < 1:
            continue

        boundary_type = 0

        exon_l = False
        exon_r = False

        for exon in viz["exons"]:
            if exon['left_boundary'] == boundary_id:
                exon_l = True
            if exon['right_boundary'] == boundary_id:
                exon_r = True

        intron_l = False
        intron_r = False

        for intron in viz["introns"]:
            if intron['left_boundary'] == boundary_id:
                intron_l = True
            if intron['right_boundary'] == boundary_id:
                intron_r = True

        print('exon_l: ', exon_l)
        print('intron_r: ', intron_r)
        print('-')
        print('intron_l: ', intron_l)
        print('exon_r: ', exon_r)

        if exon_r and intron_l:
            boundary_type += 1
        if intron_r and exon_l:
            boundary_type += 2

        if boundary_type == 3:
            boundary['type'] = 'both'
            
        elif boundary_type == 2:
            boundary['type'] = '3'
        elif boundary_type == 1:
            boundary['type'] = '5'
        else:
            boundary['type'] = 'unknown'

        print(boundary['type'])
        print("#####################")

    viz = [viz]

    with open('job-result-viz.json', 'w') as outfile:
        json.dump(viz, outfile, sort_keys=True, indent=4)

    return output
    

def main():
    path = os.path.dirname(os.path.abspath(__file__))
    return convert_json(path, '/output.txt', '/genomic.txt')

if __name__ == '__main__':
    x = main()

def f7(seq):
    seen = set()
    seen_add = seen.add
    return [ x for x in seq if not (x in seen or seen_add(x))]
