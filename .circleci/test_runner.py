#!/usr/bin/python3
import logging
import os
import sys
import time
import traceback

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

    request = requests.post(test_runner + '/job', json=payload)

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
            raise Exception('Test runner did not complete within six minutes')
        request = requests.get(
            '{}/job/{}/status'.format(test_runner, job_id),
            headers={'Cache-Control': 'no-cache'}
        )

        resp = request.content.decode('utf-8')

        if 'Exited' in resp:
            logging.info('Job completed successfully')
            break

        elif 'Failed' in resp:
            logging.info(f'Job failed, reason: {resp}')
            raise Exception(f'Job failed, reason: {resp}')


def check_job_result(test_runner: str, job_id: str):
    ''' Check the result of the job. This is the result of the tests that are
    executed against the push. If they all pass 'true' is returned.
    '''
    request = requests.get(
        test_runner + '/job/{}/success'.format(job_id),
        headers={'Cache-Control': 'no-cache'}
    )

    resp = request.content.decode('utf-8')

    if 'true' in resp:
        logging.info('Tests completed successfully')

    elif 'false' in resp:
        logging.critical('Tests failed')
        raise Exception('Tests failed')


def get_envs() -> dict:
    ''' Get the environment variables for the workflow
    '''
    envs = {}
    test_runner = os.getenv('TEST_RUNNER_SERVICE')
    if test_runner is None:
        logging.critical('Test runner service ENV missing')
        raise Exception('Test runner service ENV missing')

    envs['TEST_RUNNER_SLACK_WEBHOOK_01'] = os.getenv(
        'TEST_RUNNER_SLACK_WEBHOOK_01', None)
    envs['TEST_RUNNER_SLACK_WEBHOOK_02'] = os.getenv(
        'TEST_RUNNER_SLACK_WEBHOOK_02', None)
    envs['CIRCLE_BUILD_URL'] = os.getenv('CIRCLE_BUILD_URL', None)

    if envs['TEST_RUNNER_SLACK_WEBHOOK_02'] is None or \
            envs['TEST_RUNNER_SLACK_WEBHOOK_01'] is None:
        logging.warning('Some slack webhook URL(s) are empty')

    envs['TEST_RUNNER_SERVICE'] = test_runner
    return envs


def start_workflow():
    ''' Get the party started
    '''
    try:
        logging.info('Workflow started')
        envs = get_envs()
        job_id = str(create_job(envs['TEST_RUNNER_SERVICE']))
        check_job_completed(envs['TEST_RUNNER_SERVICE'], job_id)
        check_job_result(envs['TEST_RUNNER_SERVICE'], job_id)

        # Post success to slack
        success_text = """
        Functional tests for elixir-omg completed successfully!\n{}
        """.format(
            envs['CIRCLE_BUILD_URL']
        )
        for webhook in [
            envs['TEST_RUNNER_SLACK_WEBHOOK_01'],
            envs['TEST_RUNNER_SLACK_WEBHOOK_02']
        ]:
            if webhook is not None:
                requests.post(webhook, json={
                    'text': success_text
                })

    except Exception as e:
        tb = traceback.format_exc()
        logging.critical(
            f'Test runner service crashed, exception: {e}\ntraceback: {tb}')

        # Formatted text
        circleci_build_url = envs['CIRCLE_BUILD_URL']
        pretext = """
        elixir-omg functional tests failed, exception: `{}`
        CircleCI build results: {}
        """.format(e, circleci_build_url)
        # Sends notification to the web slack hooks
        for webhook in [
            envs['TEST_RUNNER_SLACK_WEBHOOK_01'],
            envs['TEST_RUNNER_SLACK_WEBHOOK_02']
        ]:
            if webhook is not None:
                requests.post(webhook, json={
                    'attachments': [
                        {
                            'title': 'Traceback',
                            'pretext': pretext,
                            'text': '```{}```'.format(tb),
                            "mrkdwn_in": [
                                "text",
                                "pretext"
                            ]
                        }
                    ]
                })

        # Returns a non-zero exit code so CircleCI fails
        sys.exit(1)


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
