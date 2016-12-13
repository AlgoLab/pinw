#!/usr/bin/env python3

import os
import sys
import json
import collections


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
    # Utilizziamo OrderDict per mantenere l'ordine delle chiave secondo l'ordine della dichiarazione
    viz = collections.OrderedDict()

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
    #viz["isoforms"] = []

    #Contiene la posizione di start sia degli esoni che degli introni  (json key: relative_start)
    starts = []
    #Contiene la posizione di end sia degli esoni che degli introni  (json key: relative_end)
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


    #lcoordinate corrispondo a tutti i distinti relative_end ordinati (sia degli esoni che degli introni)
    lcoordinate = sorted(list(set(ends)))
    #rcoordinate corrisponde a tutti i distinti relative_start ordinati  (sia degli esoni che degli introni)
    rcoordinate = sorted(list(set(starts)))

    print('##### LCOORD #####')
    print(lcoordinate)

    print('##### RCOORD #####')
    print(rcoordinate)

    starts = []
    stops = []
    stop = None
    # Create start and stop of each regions
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

    ############################################################################
    # Create regions
    region_id = 0
    for start, stop in zip(starts, stops[1:]):
        # Utilizziamo OrderDict per mantenere l'ordine delle chiave secondo l'ordine della dichiarazione
        region = collections.OrderedDict()
        region['start'] = start
        # the correct key is end, not start!
        region['end'] = stop
        region['sequence'] = genomics[start-1:stop-1] # -1 because Pintron output is 1-based
        region['type'] = None          # Temp value
        region['alternative'] = False  # Temp value,  sole se type codifying
        region['coverage'] = 100       # Temp value, sole se type codifying
        region['last'] = False
        region['id'] = region_id

        viz['regions'].append(region)

        region_id += 1

    # set last=True for last region
    last_region_id = region_id - 1
    for region in viz['regions']:
        if region['id'] == last_region_id:
            region['last'] = True


    ############################################################################
    # Create Boundaries
    # Utilizziamo OrderDict per mantenere l'ordine delle chiave secondo l'ordine della dichiarazione
    boundary = collections.OrderedDict()
    boundary['lcoordinate'] = 'unknow'
    boundary['rcoordinate'] = starts[0]
    boundary['first'] = -1
    boundary['type'] = 'unknow'
    viz['boundaries'].append(boundary)

    boundary_first = 0
    for lcoordinate, rcoordinate in zip(stops[1:], starts[1:]):
        # Utilizziamo OrderDict per mantenere l'ordine delle chiavi secondo l'ordine della dichiarazione
        boundary = collections.OrderedDict()

        boundary['lcoordinate'] = lcoordinate
        boundary['rcoordinate'] = rcoordinate
        boundary['first'] = boundary_first
        if boundary_first == 0:
            boundary['type'] = 'init'
        # boundary['type'] diverso da init viene stabilito successivamente
        viz['boundaries'].append(boundary)
        boundary_first += 1



    #print(viz['boundaries'][-1]['rcoordinate'])
    boundary = collections.OrderedDict()
    boundary['lcoordinate'] = viz['boundaries'][-1]['rcoordinate']
    boundary['rcoordinate'] = 'unknow'
    boundary['first'] = boundary_first
    boundary['type'] = 'term'

    viz['boundaries'].append(boundary)


    ####################################################################
    # Calcolo del numero di introni e di esoni per ogni regione
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


    #######################################################################
    # Calcolo del tipo di regione
    for region in viz['regions']:

        if region['exon number'] > 0:
            # the correct key is codifying not coding
            region['type'] = 'codifying'  # codifying if exon number > 0
            #  alternative It is defined only if type has value coding
            region['alternative'] = False #Default is false but
            # alternative is True if exon number < number of isoforms
            if int(region['exon number']) < len(isoforms):
                region['alternative'] = True
        elif region['intron number'] > 0 and region['exon number'] == 0 :
            #region['type'] = 'intron'
            region['type'] = 'spliced' #correct type
            region.pop("alternative", None)
            region.pop("coverage", None)
        else:
            region['type'] = 'unknow'
            region.pop("alternative", None)
            region.pop("coverage", None)


    #######################################################################
    # Calcolo del tipo di boundary
    for boundary in viz["boundaries"][:-1]:
        left_region_id = boundary['first']
        right_region_id = left_region_id + 1

        if left_region_id < 1:
            continue

        print(boundary)
        print('-')
        print('left', left_region_id)
        print('right', right_region_id)


        # type = "5" if the right region has exon number=0 and intron number>0,
        # while the left region has exon number>0, that is the boundary is an exon-intron splicing site.
        if (viz['regions'][right_region_id]["exon number"] == 0 and \
            viz['regions'][right_region_id]["intron number"] > 0 ) and \
            viz['regions'][left_region_id]["exon number"] > 0 :
               boundary['type'] = '5'

        # type = "3" if the right region has exon number>0,
        # while the left region has exon number=0 and intron number>0,
        # that is the boundary is an intron-exon splicing site.
        if (viz['regions'][right_region_id]["exon number"] > 0 and \
            viz['regions'][left_region_id]["intron number"] > 0 ) and \
            viz['regions'][left_region_id]["exon number"] == 0 :
               boundary['type'] = '3'

        # type = "both" if the left and right regions both have exon number>0
        # and intron number>0, that is the boundary is a both
        # and exon-intron and an intron-exon splicing site.
        if (viz['regions'][right_region_id]["exon number"] > 0 and \
            viz['regions'][right_region_id]["intron number"] > 0 ) and \
            viz['regions'][left_region_id]["exon number"] > 0 and \
            viz['regions'][left_region_id]["intron number"] > 0 :
               boundary['type'] = 'both'





    ##########################################################################
    # Creazione degli esoni

    # foreach isoform in pintron json
    for isoform in isoforms:
        exons = isoforms[isoform]['exons']
        # foreach exon in this isoform
        for exon in exons:
            viz_exon = collections.OrderedDict()

            # retrieve left boundary
            exon_relative_start = exon['relative_start']
            for index, boundary in enumerate(viz['boundaries']) :
                if exon_relative_start == boundary['rcoordinate'] :
                    # regions[boundaries[left_boundary][first] + 1][type] == "codifying"
                    index_boundary = boundary['first'] +1
                    if viz['regions'][index_boundary]['type'] == "codifying" :
                         viz_exon['left_boundary'] = index

            # retrieve right boundary
            exon_relative_end = exon['relative_end']
            for index, boundary in enumerate(viz['boundaries']) :
                if exon_relative_end == boundary['lcoordinate'] :
                    # regions[boundaries[right_boundary][first]][type] == "codifying"
                    index_boundary = boundary['first']
                    if viz['regions'][index_boundary]['type'] == "codifying" :
                         viz_exon['right_boundary'] = index


            viz_exon['annotated'] = False

            viz['exons'].append(viz_exon)

    viz["exons"] = [dict(y) for y in set(tuple(x.items()) for x in viz["exons"])]
    ############################################################################
    # Create Introns
    # foreach intron in pintron json
    for intron in introns:

        # prepare intron object
        intron = introns[intron]

        viz_intron = collections.OrderedDict()

        # retrieve left boundary
        intron_relative_start = intron['relative_start']
        for index, boundary in enumerate(viz['boundaries']) :
            if intron_relative_start == boundary['rcoordinate'] :
                index_boundary = boundary['first'] +1

                if viz['regions'][index_boundary]['type'] != 'unknow' :
                  #if viz['regions'][index_boundary]['type'] == "codifying" and \
                    # viz['regions'][index_boundary]['alternative'] == True :
                        viz_intron['left_boundary'] = index


        # retrieve right boundary
        intron_relative_end = intron['relative_end']
        for index, boundary in enumerate(viz['boundaries']) :
            if intron_relative_end == boundary['lcoordinate'] :
                index_boundary = boundary['first']
                if viz['regions'][index_boundary]['type'] != 'unknow' :
                  #if viz['regions'][index_boundary]['type'] == "codifying" and \
                     #viz['regions'][index_boundary]['alternative'] == True :
                            viz_intron['right_boundary'] = index

        # retrieve prefix and suffix
        viz_intron['prefix'] = intron['prefix']
        viz_intron['suffix'] = intron['suffix']
        viz['introns'].append(viz_intron)



    ################################################################
    for index,exon in enumerate( viz['exons'] ) :
        if 'left_boundary' not in exon or 'right_boundary' not in exon :
            del viz['exons'][index]

    for index,intron in enumerate( viz['introns'] ) :
        if 'left_boundary' not in intron or 'right_boundary' not in intron :
            del viz['introns'][index]

    # TODO: DA VERIFICARE SE LE SEGUENTI CHIAVI VANNO TENUTE O ELIMINATE
    """"
    for region in viz['regions']:
        region.pop("intron number", None)
        region.pop("exon number", None)

    for boundary in viz['boundaries'] :
        boundary.pop("lcoordinate", None)
        boundary.pop("rcoordinate", None)
    """

    viz = [viz]

    with open(path+'job-result-viz.json', 'w') as outfile:
        json.dump(viz, outfile, sort_keys=False, indent=4)

    return output


def main():
    #path = os.path.dirname(os.path.abspath(__file__))
    path           = sys.argv[1]
    pintron_output ='output.txt'
    genomics       = 'genomics.fasta'
    return convert_json(path, pintron_output, genomics)
    #return convert_json(path, '/output.txt', '/genomics.fasta')

if __name__ == '__main__':
    main()
