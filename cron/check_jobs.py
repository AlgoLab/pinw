#!/usr/bin/env python3

import os, time, json, shutil


completed_jobs = []
dead_jobs = []
running_jobs = []

# Loop over each directory:
subdirs = [x for x in os.listdir('jobs') if os.path.isdir(os.path.join('jobs', x))]
for directory in subdirs:
    jobdir = os.path.join('jobs', directory)

    result_file = jobdir + '/job-result.json'
    jid = int(directory.split('-')[1])

    # If 'pinw-ack' is present, the job result has already been registered:
    if os.path.isfile(jobdir + '/pinw-ack'):
        with open(jobdir + '/pinw-ack') as ack:
            result_id = ack.read().split('|')[0]
            dest = "results/result-" + result_id
            shutil.rmtree(dest)
            shutil.copytree(jobdir, dest)
            shutil.rmtree(jobdir)

    # Check for locks
    elif os.path.isfile(jobdir + '/python_lock'):
        statbuf = os.stat(jobdir + '/python_lock')
        if time.time() - statbuf.st_mtime > 60: # last modified < 60 seconds ago
            dead_jobs.append(jid)
        else:
            running_jobs.append(jid)

    # No locks, job has either finished (successfully or not) or died
    elif os.path.isfile(result_file):
        with open(result_file) as result_file_stream:
            completed_jobs.append({'id': jid, 'result': json.load(result_file_stream)})
    else:
        dead_jobs.append(jid)

# Write the report:
results = {'completed': completed_jobs, 'dead': dead_jobs, 'running': running_jobs}
with open("pinw-report.json", 'w') as report:
    json.dump(results, report)
