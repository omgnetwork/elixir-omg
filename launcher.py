#!/usr/bin/python3
##!/usr/local/bin/python3
import json
import logging
import os
import subprocess
import sys

import git
import requests


class ChildchainLauncher:
    ''' ChildchainLauncher: A module to launch a Childchain service
    '''
    def __init__(self, git_commit_hash: str, platform: str):
        self.git_commit_hash = git_commit_hash
        self.platform = platform

    def start(self):
        ''' Start the launch process for the Childchain service
        '''
        logging.info('Service type to launch is Plasma Childchain')
        logging.info(
            'Starting launch process for build {}'.format(self.git_commit_hash)
        )
        self.ethereum_client = check_ethereum_client(self.platform)
        logging.info('Ethereum client is {}'.format(self.ethereum_client))
        if self.compile_application() is False:
            logging.critical('Could not compile application. Exiting.')
            sys.exit(1)
        if self.deploy_plasma_contract() is False:
            logging.critical('Contract not deployed. Exiting.')
            sys.exit(1)
        if self.initialise_childchain_database() is False:
            logging.critical('Could not initialise database. Exiting.')
            sys.exit(1)
        self.start_childchain_service()

    def compile_application(self) -> bool:
        ''' Execute a mix compile
        '''
        result = subprocess.run(['mix', 'compile'], stdout=subprocess.DEVNULL)
        if result.returncode == 0:
            logging.info('Elixir mix compile successful')
            return True
        return False

    def deploy_plasma_contract(self) -> bool:
        ''' Deploy the smart contract and populate the ~/config.exs file
        '''
        result = subprocess.run(
            ['./deploy_and_populate.sh'], stdout=subprocess.PIPE
        )
        if result.returncode == 0:
            logging.info(
                'Smart contract deployed and authority address populated'
            )
            return True
        logging.critical(
            'Could not deploy the smart contract. Elixir output: {}'.format(
                result.stdout
            )
        )
        return False

    def initialise_childchain_database(self) -> bool:
        ''' Initialise the childchian database (chain data store)
        '''
        result = subprocess.run(
            ["mix", "run", "--no-start", "-e", "'OMG.DB.init()'"],
            stdout=subprocess.PIPE
        )
        if result.returncode == 0:
            logging.info('Childchain database initialised')
            return True
        logging.critical(
            'Could not initialise the database. Error: {}'.format(
                result.stdout
            )
        )
        return False

    def start_childchain_service(self):
        ''' Start the childchain service
        '''
        os.chdir(os.getcwd() + '/apps/omg_api')
        process = subprocess.Popen(
            [
                "/usr/local/bin/iex ", "-S ", "mix", "run", "--config",
                "~/config.exs"
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=True
        )
        while True:
            output = process.stdout.readline()
            if output == '' and process.poll() is not None:
                break
            if output:
                print(output.strip())


class WatcherLauncher:
    ''' TODO(jbunce): WatcherLauncher: module to launch a Watcher service
    '''
    def __init__(self):
        pass


def check_ethereum_client(platform: str) -> str:
    ''' Return the Ethereum client that is running
    '''
    client_location = "http://docker.for.mac.localhost:8545" if platform == 'MAC' else "http://localhost:8545" # noqa E501
    headers = {"Content-Type": "application/json"}
    post_data = {
        "jsonrpc": "2.0", "method": "web3_clientVersion", "params": [],
        "id": 67
    }
    try:
        ethereum_client_version = requests.post(
            client_location, data=json.dumps(post_data), headers=headers
        )
    except requests.exceptions.ConnectionError:
        logging.critical('Could not connect to the Ethereum client. Exiting')
        sys.exit(1)
    logging.info('Connected to the Ethereum client')

    return ethereum_client_version.content


def get_environment_variables() -> dict:
    ''' Get the environment variables required to start service
    '''
    repo = git.Repo(search_parent_directories=True)
    return {
        'plasma_service': os.getenv('PLASMA_SERVICE'),
        'platform': os.getenv('PLATFORM'),
        'git_commit_hash': repo.head.object.hexsha
    }


def set_logger(log_level: str = 'INFO'):
    ''' Sets the logging module parameters
    '''
    root = logging.getLogger('')
    for handler in root.handlers:
        root.removeHandler(handler)
    format = '%(asctime)s %(levelname)-8s:%(message)s'
    logging.basicConfig(format=format, level=log_level)


def main():
    ''' Start the launcher!
    '''
    logging.info('Starting Launcher')
    environment_variables = get_environment_variables()
    if environment_variables['plasma_service'] == 'CHILDCHAIN':
        childchain = ChildchainLauncher(
            environment_variables['git_commit_hash'],
            environment_variables['platform']
        )
        childchain.start()
        return
    logging.error('Plasma service to execute not provided')


if __name__ == '__main__':
    set_logger()
    main()
