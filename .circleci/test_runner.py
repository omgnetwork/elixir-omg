#!/usr/local/bin/python3
import logging
import os
import sys
import time

import requests


def create_job(test_runner: str) -> str:
    ''' Create a job in the test runner. Returns the job ID
    '''
    payload = {
        "job": {
            "command": "npm",
            "args": ["run", "ci-test-fast"],
            "cwd": "/home/omg/omg-js"
        }
    }
    try:
        request = requests.post(test_runner + '/job', json=payload)
    except ConnectionError:
        logging.critical('Could not connect to the test runner')
        sys.exit(1)  # Return a non-zero exit code so CircleCI fails

    logging.info('Job created: {}'.format(
        request.content.decode('utf-8'))
    )
    return request.content.decode('utf-8')


def check_job_completed(test_runner: str, job_id: str):
    ''' Get the status of the job from the test runner
    '''
    start_time = int(time.time())
    while True:
        if start_time >= (start_time + 360):
            logging.critical('Test runner did not complete within six minutes')
            sys.exit(1)  # Return a non-zero exit code so CircleCI fails
        try:
            request = requests.get(
                '{}/job/{}/status'.format(test_runner, job_id),
                headers={'Cache-Control': 'no-cache'}
            )
        except ConnectionError:
            logging.critical('Could not connect to the test runner')
            sys.exit(1)  # Return a non-zero exit code so CircleCI fails
        if 'Exited' in request.content.decode('utf-8'):
            logging.info('Job completed successfully')
            break


def check_job_result(test_runner: str, job_id: str):
    ''' Check the result of the job. This is the result of the tests that are
    executed against the push. If they all pass 'true' is returned.
    '''
    try:
        request = requests.get(
            test_runner + '/job/{}/success'.format(job_id),
            headers={'Cache-Control': 'no-cache'}
        )
    except ConnectionError:
        logging.critical('Could not connect to the test runner')
        sys.exit(1)
    if 'true' in request.content.decode('utf-8'):
        logging.info('Tests completed successfully')


def get_envs() -> dict:
    ''' Get the environment variables for the workflow
    '''
    envs = {}
    test_runner = os.getenv('TEST_RUNNER_SERVICE')
    if test_runner is None:
        logging.critical('Test runner service ENV missing')
        sys.exit(1)  # Return a non-zero exit code so CircleCI fails

    envs['TEST_RUNNER_SERVICE'] = test_runner
    return envs


def start_workflow():
    ''' Get the party started
    '''
    logging.info('Workflow started')
    envs = get_envs()
    job_id = str(create_job(envs['TEST_RUNNER_SERVICE']))
    check_job_completed(envs['TEST_RUNNER_SERVICE'], job_id)
    check_job_result(envs['TEST_RUNNER_SERVICE'], job_id)


def set_logger():
    ''' Sets the logging module parameters
    '''
    root = logging.getLogger('')
    for handler in root.handlers:
        root.removeHandler(handler)
    format = '%(asctime)s %(levelname)-8s:%(message)s'
    logging.basicConfig(format=format, level='INFO')


if __name__ == '__main__':
    set_logger()
    start_workflow()
