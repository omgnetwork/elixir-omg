#!/usr/bin/python3
import json
import logging
import os
import subprocess
import sys

import git
import requests


RINKEBY_CONTRACT = (
    'use Mix.Config',
    'config :omg_eth,',
    '  contract_addr: "0x7ce50c54c8c7fd4ac6167f32497ba398aa20835b",',
    '  txhash_contract: "0xe6fde071a083883dc805c359f808d64d5813d553a2cc2cf1b44913d472a1b65b",', # noqa E501
    '  authority_addr: "0xe28e813f54b9a8f22082926c9f0881fc8cba538c"'
)


class ChildchainLauncher:
    ''' ChildchainLauncher: A module to launch a Childchain service
    '''
    def __init__(
        self, git_commit_hash: str, platform: str, ethereum_network: str,
            contract_exchanger_url: str):
        self.git_commit_hash = git_commit_hash
        self.platform = platform
        self.ethereum_network = ethereum_network
        self.public_networks = ['RINKEBY', 'KOVAN', 'ROPSTEN']
        self.contracts = {}
        self.contracts['RINKEBY'] = RINKEBY_CONTRACT
        self.contract_exchanger_url = contract_exchanger_url

    def start(self):
        ''' Start the launch process for the Childchain service
        '''
        logging.info('Service type to launch is Elixir Childchain')
        logging.info(
            'Starting launch process for build {}'.format(self.git_commit_hash)
        )
        self.ethereum_client = check_ethereum_client(self.platform)
        logging.info('Ethereum client is {}'.format(self.ethereum_client))
        if self.compile_application() is False:
            logging.critical('Could not compile application. Exiting.')
            sys.exit(1)
        if self.deploy_contract() is False:
            logging.critical('Contract not deployed. Exiting.')
            sys.exit(1)
        self.update_contract_exchanger()
        if self.initialise_childchain_database() is False:
            logging.critical('Could not initialise database. Exiting.')
            sys.exit(1)
        self.start_childchain_service()

    def compile_application(self) -> bool:
        ''' Execute a mix compile
        '''
        result = subprocess.run(['mix', 'compile'])
        if result.returncode == 0:
            logging.info('Elixir mix compile successful')
            return True
        return False

    def deploy_contract(self) -> bool:
        ''' Deploy the smart contract and populate the ~/config.exs file
        '''
        if self.ethereum_network == [x for x in self.public_networks]:
            return self.use_pre_deployed()

        result = subprocess.run(
            ['./deploy_and_populate.sh'],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
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

    def update_contract_exchanger(self):
        ''' Update the contract exchanger service with the details of the
        deployed contract
        '''
        contract_details = {}
        with open(os.path.expanduser('~') + '/config.exs') as contract:
            contract_list = [x.strip('\n') for x in contract.readlines()]
            for entry in contract_list:
                if 'Mix.Config' or 'omg_eth' in entry:
                    continue
                if 'contract_addr' in entry:
                    entry.split(' ')
                    contract_details['contract_addr'] = entry[3]
                if 'txhash_contract' in entry:
                    entry.split(' ')
                    contract_details['txhash_contract'] = entry[3]
                if 'authority_addr' in entry:
                    entry.split(' ')
                    contract_details['authority_addr'] = entry[3]

        requests.post(
            self.contract_exchanger_url + '/set_contract',
            data=json.dumps(contract_details)
        )
        logging.info('Updated Contract Exchanger with ~./config.exs data')

    def use_pre_deployed(self) -> bool:
        ''' Use a pre-deployed Plasma contract on Rinkeby
        '''
        logging.info(
            'Using pre-deployed contract on network {}'.format(
                self.ethereum_network
            )
        )
        return self.config_writer_predeployed()

    def config_writer_predeployed(self) -> bool:
        ''' Write a config.exs to the homedir
        '''
        logging.info('Writing config.exs')
        home = os.path.expanduser('~')
        with open(home + 'config.exs', 'w+') as mix:
            for line in self.contracts[self.ethereum_network]:
                mix.write(line)
                mix.write('\n')
        return True

    def initialise_childchain_database(self) -> bool:
        ''' Initialise the childchian database (chain data store)
        '''
        result = subprocess.run(
            "mix run --no-start -e 'OMG.DB.init()'",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=True
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
            'iex -S mix xomg.child_chain.start --config ~/config.exs',
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
    ''' WatcherLauncher: module to launch a Watcher service
    '''
    def __init__(
            self, git_commit_hash: str, platform: str, ethereum_network: str,
            contract_exchanger_url: str):
        self.git_commit_hash = git_commit_hash
        self.platform = platform
        self.ethereum_network = ethereum_network
        self.public_networks = ['RINKEBY', 'KOVAN', 'ROPSTEN']
        self.contracts = {}
        self.contracts['RINKEBY'] = RINKEBY_CONTRACT
        self.watcher_additional_config = (
            'config :omg_db,',
            '  leveldb_path: Path.join([System.get_env("HOME"), ".omg/data_watcher"]))' # noqa E501
        )
        self.contract_exchanger_url = contract_exchanger_url

    def start(self):
        ''' Start the launch process for the Childchain service
        '''
        logging.info('Service type to launch is Elixir Watcher')
        logging.info(
            'Starting launch process for build {}'.format(self.git_commit_hash)
        )
        self.ethereum_client = check_ethereum_client(self.platform)
        logging.info('Ethereum client is {}'.format(self.ethereum_client))
        if self.compile_application() is False:
            logging.critical('Could not compile application. Exiting.')
            sys.exit(1)
        if self.deploy_contract() is False:
            logging.critical('Contract not deployed. Exiting.')
            sys.exit(1)
        if self.initialise_childchain_database() is False:
            logging.critical('Could not initialise database. Exiting.')
            sys.exit(1)
        self.start_childchain_service()

    def compile_application(self) -> bool:
        ''' Execute a mix compile
        '''
        result = subprocess.run(['mix', 'compile'])
        if result.returncode == 0:
            logging.info('Elixir mix compile successful')
            return True
        return False

    def deploy_contract(self) -> bool:
        ''' Deploy the smart contract and populate the ~/config.exs file
        '''
        if self.ethereum_network == [x for x in self.public_networks]:
            return self.use_pre_deployed()

        return self.config_writer_dynamic()

    def use_pre_deployed(self) -> bool:
        ''' Use a pre-deployed Plasma contract on Rinkeby
        '''
        logging.info(
            'Using pre-deployed contract on network {}'.format(
                self.ethereum_network
            )
        )
        return self.config_writer_predeployed()

    def get_contract_from_exchanger(self) -> dict:
        ''' Get the contract that has been deployed by a Childchain instance
        '''
        request = requests.get(self.contract_exchanger_url + '/get_contract')
        if request.status_code != '200':
            logging.error(
                'HTTP Status code from the contract exchanger is not 200'
            )
        return request.content

    def config_writer_dynamic(self) -> bool:
        ''' Write the configuration from data retrieved from the contract
        exchanger
        '''
        request = self.get_contract_from_exchanger()
        print(request)
        contract_data = json.loads(str(request))
        config = [
            'use Mix.Config',
            'config :omg_eth,',
            '  contract_addr: {},'.format(contract_data['contract_addr']),
            '  txhash_contract: {},'.format(contract_data['txhash_contract']),
            '  authority_addr: "{}'.format(contract_data['authority_addr'])
        ]
        logging.info('Writing config_watcher.exs')
        home = os.path.expanduser('~')
        with open(home + 'config_watcher.exs', 'w+') as mix:
            for line in config + self.watcher_additional_config:
                mix.write(config)
                mix.write('\n')
        logging.info('Written config_watcher.exs')
        return True

    def config_writer_predeployed(self) -> bool:
        ''' Write a config.exs to the homedir
        '''
        logging.info('Writing config_watcher.exs')
        home = os.path.expanduser('~')
        with open(home + 'config_watcher.exs', 'w+') as mix:
            for line in self.contracts[self.ethereum_network] + self.watcher_additional_config: # noqa E501
                mix.write(line)
                mix.write('\n')
        logging.info('Written config_watcher.exs')
        return True

    def initialise_watcher_postgres_database(self) -> bool:
        ''' Initialise the watcher database (Postgres)
        '''
        os.chdir(os.getcwd() + '/apps/omg_watcher')
        result = subprocess.run(
            'printf "y\r" | mix ecto.reset --no-start',
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=True
        )
        if result.returncode == 0:
            logging.info('')
            return True
        logging.critical(
            'Could not initialise the database. Error: {}'.format(
                result.stdout
            )
        )
        return False

    def initialise_watcher_chain_database(self) -> bool:
        ''' Initialise the childchian database (chain data store)
        '''
        result = subprocess.run(
            "mix run --no-start -e 'OMG.DB.init()'",
            "--config ~/config_watcher.exs",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=True
        )
        if result.returncode == 0:
            logging.info('')
            return True
        logging.critical(
            'Could not initialise the database. Error: {}'.format(
                result.stdout
            )
        )
        return False

    def start_watcher_service(self):
        ''' Start the childchain service
        '''
        process = subprocess.Popen(
            'mix run --no-halt --config ~/config_watcher.exs',
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


def check_ethereum_client(platform: str) -> str:
    ''' Return the Ethereum client that is running
    '''
    client_location = "http://docker.for.mac.localhost:8545" if platform == 'MAC' else "http://geth-local.default.svc.cluster.local:8545" # noqa E501
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
        'elixir_service': os.getenv('ELIXIR_SERVICE'),
        'platform': os.getenv('PLATFORM'),
        'ethereum_network': os.getenv('ETHEREUM_NETWORK'),
        'git_commit_hash': repo.head.object.hexsha,
        'contract_exchanger_url': os.getenv('CONTRACT_EXCHANGER_URL')
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
    if environment_variables['elixir_service'] == 'CHILDCHAIN':
        childchain = ChildchainLauncher(
            environment_variables['git_commit_hash'],
            environment_variables['platform'],
            environment_variables['ethereum_network'],
            environment_variables['contract_exchanger_url']
        )
        childchain.start()
        return
    if environment_variables['elixir_service'] == 'WATCHER':
        watcher = WatcherLauncher(
            environment_variables['git_commit_hash'],
            environment_variables['platform'],
            environment_variables['ethereum_network'],
            environment_variables['contract_exchanger_url']
        )
        watcher.start()
        return
    logging.error('Elixir service to execute not provided')


if __name__ == '__main__':
    set_logger()
    main()
