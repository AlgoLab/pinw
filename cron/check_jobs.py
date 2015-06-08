#! usr/bin/env python3

import os, time, json


completed_jobs = []
dead_jobs = []
running_jobs = []

# Loop over each directory:
job_dirs = os.listdir('jobs')
for jobdir in job_dirs:
    result_file = jobdir + '/job-result.json'
    jid = int(dir.split('-')[1])

    # Check for locks
    if os.path.isfile(jobdir + '/python_lock'):
        statbuf = os.stat(jobdir + '/python_lock')
        if time.time() - statbuf.st_mtime > 60: # last modified < 60 seconds ago
            dead_jobs.append(jid)
        else:
            running_jobs.append(jid)
        continue

    # No locks, job has either finished (successfully or not) or died
    if os.path.isfile(result_file):
        with open(result_file) as result_file_stream:
            completed_jobs.append({'id': jid, 'result': json.load(result_file_stream)})
    else:
        dead_jobs.append(jid)

# Write the report:
results = {'completed': completed_jobs, 'dead': dead_jobs, 'running': running_jobs}
with open("report.json", 'w') as report:
    json.dump(results, report)
