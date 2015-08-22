#!/usr/bin/env python3

import os, json

def convert_json(output_file):
	output = None
	with open(output_file, 'r') as fp:
		output = json.load(fp)
	
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

	# create regions
	for start in lcoordinate:
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
		region['stop'] = stop
		region['id'] = region_id
		region['last'] = False
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
			if intron_relative_end == region['stop']:
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
				int(intron['relative_end'] >= int(region['stop'])):
				region['intron number'] += 1

		# foreach isoform in pintron json
		for isoform in isoforms:
			exons = isoforms[isoform]['exons']
			# foreach exon in this isoform
			for exon in exons:
				if int(exon['relative_start'] <= int(region['start'])) and \
					int(exon['relative_end'] >= int(region['stop'])):
					region['exon number'] += 1


	# region type

	# alternative? check may be broken!!!

	# foreach region
	for region in viz['regions']:
		if region['exon number'] > 0:
			region['type'] = 'coding'
			region['alternative?'] = False
			if region['exon number'] < region['intron number']:
				region['alternative?'] = True
		elif region['intron number'] > 0:
			region['type'] = 'intron'
		else:
			region['type'] = 'unknown'

	# exons

	# foreach isoform in pintron json
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
			print('start: ', exon_relative_start, ' - region: ', left_boundary)

			# retrieve right boundary
			exon_relative_end = exon['relative_end']
			right_boundary = -1
			for region in viz['regions']:
				if exon_relative_end == region['stop']:
					right_boundary = region['id']
					break
			viz_exon['right_boundary'] = right_boundary
			print('end: ', exon_relative_end, ' - region: ', right_boundary)

			viz['exons'].append(viz_exon)




	with open('job-result-viz.json', 'w') as outfile:
		json.dump(viz, outfile, sort_keys=True, indent=4)

	return output
	

def main():
    path = os.path.dirname(os.path.abspath(__file__))
    return convert_json(path + '/output.txt')

if __name__ == '__main__':
    x = main()