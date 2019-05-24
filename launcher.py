#!/usr/bin/python3
import json
import logging
import os
import subprocess
import sys

import git
from retry import retry
import requests


RINKEBY_CONTRACT = {}
GORLI_CONTRACT = {}


class ChildchainLauncher:
    ''' ChildchainLauncher: A module to launch a Childchain service
    '''
    def __init__(
        self, git_commit_hash: str, ethereum_network: str,
            contract_exchanger_url: str, ethereum_rpc_url: str):
        self.chain_data_present = False
        self.git_commit_hash = git_commit_hash
        self.ethereum_network = ethereum_network
        self.public_networks = ['RINKEBY', 'KOVAN', 'ROPSTEN', 'GORLI']
        self.contracts = {}
        self.contracts['RINKEBY'] = RINKEBY_CONTRACT
        self.contracts['GORLI'] = GORLI_CONTRACT
        self.contract_exchanger_url = contract_exchanger_url
        self.ethereum_rpc_url = ethereum_rpc_url

    def start(self):
        ''' Start the launch process for the Childchain service

        TODO(jbunce): This needs tidying for clarity (issue #12)
        '''
        logging.info('Service type to launch is Elixir Childchain')
        logging.info(
            'Starting launch process for build {}'.format(self.git_commit_hash)
        )
        self.update_appsignal_deployment()
        self.check_chain_data_path()
        self.ethereum_client = check_ethereum_client(self.ethereum_rpc_url)
        logging.info('Ethereum client is {}'.format(self.ethereum_client))
        if self.chain_data_present is True:
            if self.ethereum_network not in self.public_networks:
                if self.config_writer_dynamic() is True:
                    logging.info('Launcher process complete')
                    return
        if self.compile_application() is False:
            logging.critical('Could not compile application. Exiting.')
            sys.exit(1)
        deployment_result = self.deploy_contract()
        if deployment_result is False:
            logging.critical('Contract not deployed. Exiting.')
            sys.exit(1)
        elif deployment_result == 'PREDEPLOYED':
            self.initialise_childchain_database()
            logging.info('Launcher process complete')
            return
        self.update_contract_exchanger()
        if self.chain_data_present is False:
            if self.initialise_childchain_database() is False:
                logging.critical('Could not initialise database. Exiting.')
                sys.exit(1)

        logging.info('Launcher process complete')

    def update_appsignal_deployment(self):
        ''' Inform AppSignal of the new deployment
        '''
        if not os.getenv('APPSIGNAL_DEPLOYMENT_URL'):
            logging.warning('AppSignal deployment configuration not found')
            return

        post_body = {'revision': self.git_commit_hash, 'user': 'launcher.py'}
        request = requests.post(
            os.getenv('APPSIGNAL_DEPLOYMENT_URL'), data=json.dumps(post_body)
        )
        logging.info("AppSignal deployment set: {}".format(request.content))

    def get_contract_from_exchanger(self) -> dict:
        ''' Get the contract that has been deployed by a Childchain instance
        '''
        request = requests.get(self.contract_exchanger_url + '/get_contract')
        if request.status_code != 200:
            logging.error(
                'HTTP Status code from the contract exchanger is not 200'
            )
        logging.info('Response received from the contract exchanger service')

        return request.content

    def config_writer_dynamic(self) -> bool:
        ''' Write the configuration from data retrieved from the contract
        exchanger
        '''
        contract_data = None
        try:
            contract_data = json.loads(
                self.get_contract_from_exchanger().decode('utf-8')
            )
        except json.decoder.JSONDecodeError:
            logging.warning(
                'Empty response from the contract exchanger.'
                'Assuming this is a first deploy.'
            )
            return False
        config = [
            'use Mix.Config',
            'config :omg_eth,',
            '  contract_addr: "{}",'.format(contract_data['contract_addr']),
            '  txhash_contract: "{}",'.format(contract_data['txhash_contract']), # noqa E501
            '  authority_addr: "{}"'.format(contract_data['authority_addr'])
        ]
        home = os.path.expanduser('~')
        with open(home + '/config.exs', 'w+') as mix:
            for line in config:
                mix.write(line)
                mix.write('\n')
        logging.info('Written config.exs')
        return True

    def check_chain_data_path(self):
        ''' Checks if the chain data is already present
        '''
        if os.path.exists(os.path.expanduser('~') + '/.omg/data'):
            self.chain_data_present = True
            logging.info('Childchain data found')
        else:
            logging.info('Chain data not found')

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
        if self.ethereum_network in self.public_networks:
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

    def clean_config_entry(self, line: str) -> str:
        ''' Clean the line that forms the entry for the config.exs
        '''
        line = line.replace('"', '')
        line = line.replace(',', '')
        return line

    def update_contract_exchanger(self):
        ''' Update the contract exchanger service with the details of the
        deployed contract
        '''
        contract_details = {}
        with open(os.path.expanduser('~') + '/config.exs') as contract:
            contract_list = [x.strip('\n') for x in contract.readlines()]
            for entry in contract_list:
                if ('Mix.Config' in entry or 'omg_eth' in entry):
                    continue
                if 'contract_addr' in entry:
                    contract_details['contract_addr'] = \
                        self.clean_config_entry(entry.split(' ')[3])
                if 'txhash_contract' in entry:
                    contract_details['txhash_contract'] = \
                        self.clean_config_entry(entry.split(' ')[3])
                if 'authority_addr' in entry:
                    contract_details['authority_addr'] = \
                        self.clean_config_entry(entry.split(' ')[3])

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

    def config_writer_predeployed(self) -> str:
        ''' Write a config.exs to the homedir
        '''
        logging.info('Writing config.exs')
        home = os.path.expanduser('~')
        config = [
            'use Mix.Config',
            'config :omg_eth,',
            '  contract_addr: "{}",'.format(
                self.contracts[self.ethereum_network]['contract_addr']), # noqa E501
            '  txhash_contract: "{}",'.format(
                self.contracts[self.ethereum_network]['txhash_contract']), # noqa E501
            '  authority_addr: "{}"'.format(
                self.contracts[self.ethereum_network]['authority_addr']) # noqa E501
        ]
        with open(home + '/config.exs', 'w+') as mix:
            for line in config:
                mix.write(line)
                mix.write('\n')
        return 'PREDEPLOYED'

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


class WatcherLauncher:
    ''' WatcherLauncher: module to launch a Watcher service
    '''
    def __init__(
            self, git_commit_hash: str, ethereum_network: str,
            contract_exchanger_url: str, ethereum_rpc_url: str):
        self.git_commit_hash = git_commit_hash
        self.ethereum_network = ethereum_network
        self.public_networks = ['RINKEBY', 'KOVAN', 'ROPSTEN', 'GORLI']
        self.contracts = {}
        self.contracts['RINKEBY'] = RINKEBY_CONTRACT
        self.contracts['GORLI'] = GORLI_CONTRACT
        self.watcher_additional_config = [
            'config :omg_db,',
            '  leveldb_path: Path.join([System.get_env("HOME"), ".omg/data_watcher"])' # noqa E501
        ]
        self.contract_exchanger_url = contract_exchanger_url
        self.ethereum_rpc_url = ethereum_rpc_url

    def start(self):
        ''' Start the launch process for the Childchain service
        '''
        logging.info('Service type to launch is Elixir Watcher')
        logging.info(
            'Starting launch process for build {}'.format(self.git_commit_hash)
        )
        self.update_appsignal_deployment()
        self.ethereum_client = check_ethereum_client(self.ethereum_rpc_url)
        logging.info('Ethereum client is {}'.format(self.ethereum_client))
        if self.compile_application() is False:
            logging.critical('Could not compile application. Exiting.')
            sys.exit(1)
        if self.deploy_contract() is False:
            logging.critical('Contract not deployed. Exiting.')
            sys.exit(1)
        if self.check_watcher_chain_data_present() is False:
            # This is a fresh deploy of the Watcher
            if self.initialise_watcher_chain_database() is False:
                logging.critical(
                    'Could not initialise Watcher LevelDB instance'
                )
                sys.exit(1)
            if self.initialise_watcher_postgres_database() is False:
                logging.critical(
                    'Could not connect to the Postgres database Exiting.'
                )
                sys.exit(1)

        if self.update_watcher_postgres_database() is False:
            logging.critical(
                'Could not update the Postgres database Exiting.'
            )
            sys.exit(1)

        logging.info('Launcher process complete')

    def update_appsignal_deployment(self):
        ''' Inform AppSignal of the new deployment
        '''
        if not os.getenv('APPSIGNAL_DEPLOYMENT_URL'):
            logging.warning('AppSignal deployment configuration not found')
            return

        post_body = {'revision': self.git_commit_hash, 'user': 'launcher.py'}
        request = requests.post(
            os.getenv('APPSIGNAL_DEPLOYMENT_URL'), data=json.dumps(post_body)
        )
        logging.info("AppSignal deployment set: {}".format(request.content))

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
        if self.ethereum_network in self.public_networks:
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
        if request.status_code != 200:
            logging.error(
                'HTTP Status code from the contract exchanger is not 200'
            )
        logging.info('Response received from the contract exchanger service')

        return request.content

    def check_watcher_chain_data_present(self) -> bool:
        ''' Return True if ~/.omg/ exits. This allows deployment
        for both situations that are fresh and where there is existing data.
        '''
        if os.path.exists(os.path.expanduser('~') + '/.omg/data_watcher'):
            logging.info('Chain data found')
            return True
        else:
            logging.info('Chain data not found')
            return False

    def config_writer_dynamic(self) -> bool:
        ''' Write the configuration from data retrieved from the contract
        exchanger
        '''
        if self.ethereum_network in self.public_networks:
            contract_data = self.contracts[self.ethereum_network]
        else:
            contract_data = json.loads(
                self.get_contract_from_exchanger().decode('utf-8')
            )
        config = [
            'use Mix.Config',
            'config :omg_eth,',
            '  contract_addr: "{}",'.format(
                contract_data['contract_addr']),
            '  txhash_contract: "{}",'.format(
                contract_data['txhash_contract']),
            '  authority_addr: "{}"'.format(
                contract_data['authority_addr'])
        ]
        home = os.path.expanduser('~')
        with open(home + '/config_watcher.exs', 'w+') as mix:
            for line in config + self.watcher_additional_config:
                mix.write(line)
                mix.write('\n')
        logging.info('Written config_watcher.exs')
        return True

    def config_writer_predeployed(self) -> bool:
        ''' Write a config.exs to the homedir
        '''
        logging.info('Writing config_watcher.exs')
        config = [
            'use Mix.Config',
            'config :omg_eth,',
            '  contract_addr: "{}",'.format(
                self.contracts[self.ethereum_network]['contract_addr']), # noqa E501
            '  txhash_contract: "{}",'.format(
                self.contracts[self.ethereum_network]['txhash_contract']), # noqa E501
            '  authority_addr: "{}"'.format(
                self.contracts[self.ethereum_network]['authority_addr']) # noqa E501
        ]
        home = os.path.expanduser('~')
        with open(home + '/config_watcher.exs', 'w+') as mix:
            for line in config + self.watcher_additional_config: # noqa E501
                mix.write(line)
                mix.write('\n')

        return True

    def initialise_watcher_postgres_database(self) -> bool:
        ''' Initialise the watcher database (Postgres)
        '''
        os.chdir(os.path.expanduser('~') + '/elixir-omg')
        result = subprocess.run(
            "mix ecto.reset",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=True
        )
        if result.returncode == 0:
            logging.info('Watcher Postgres instance initialised')
            return True
        logging.critical(
            'Could not initialise the database. Error: {}'.format(
                result.stdout
            )
        )
        return False

    def update_watcher_postgres_database(self) -> bool:
        ''' Updates the watcher postgres database with latest migration scripts
        '''
        os.chdir(os.path.expanduser('~') + '/elixir-omg')
        result = subprocess.run(
            "mix ecto.migrate",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=True
        )
        if result.returncode == 0:
            logging.info('Watcher Postgres - all migrations up')
            return True
        logging.critical(
            'Could not migrate the database. Error: {}'.format(
                result.stdout
            )
        )
        return False

    def initialise_watcher_chain_database(self) -> bool:
        ''' Initialise the childchian database (chain data store)
        '''
        result = subprocess.run(
            "mix run --no-start -e 'OMG.DB.init()' --config ~/config_watcher.exs", # noqa E501
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            shell=True
        )
        if result.returncode == 0:
            logging.info('Initialised Watcher chain database')
            return True
        logging.critical(
            'Could not initialise the database. Error: {}'.format(
                result.stdout
            )
        )
        return False


@retry(tries=3, delay=2)
def check_ethereum_client(ethereum_rpc_url: str) -> str:
    ''' Return the Ethereum client that is running
    '''
    headers = {"Content-Type": "application/json"}
    post_data = {
        "jsonrpc": "2.0", "method": "web3_clientVersion", "params": [],
        "id": 67
    }
    try:
        ethereum_client_version = requests.post(
            ethereum_rpc_url, data=json.dumps(post_data), headers=headers
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
    if os.getenv('ETHEREUM_NETWORK') == 'RINKEBY':
        RINKEBY_CONTRACT['contract_addr'] = os.environ.get(
            'RINKEBY_CONTRACT_ADDRESS',
            '0x98abd7229afac999fc7965bea7d94a3b5e7e0218'
        )
        RINKEBY_CONTRACT['txhash_contract'] = os.environ.get(
            'RINKEBY_TXHASH_CONTRACT',
            '0x84a86f06b97e4c2d694ba507e7fcd8cf78adc4fbd596b1d3626ec7ba8242450d' # noqa E501
        )
        RINKEBY_CONTRACT['authority_addr'] = os.environ.get(
            'RINKEBY_AUTHORITY_ADDRESS',
            '0xe5153ad259be60003909492b154bf4b7f1787f70'
        )
    elif os.getenv('ETHEREUM_NETWORK') == 'GORLI':
        GORLI_CONTRACT['contract_addr'] = os.environ.get(
            'GORLI_CONTRACT_ADDRESS',
            '0x607ba3407d9aab7dec4dfe67993060b9949ad6e1'
        )
        GORLI_CONTRACT['txhash_contract'] = os.environ.get(
            'GORLI_TXHASH_CONTRACT',
            '0x42f6c66e68e56d0fbee14c847b6f0dbfbab91e615854b3f2375299808074b357' # noqa E501
        )
        GORLI_CONTRACT['authority_addr'] = os.environ.get(
            'GORLI_AUTHORITY_ADDRESS',
            '0xb32deedcbe7949ce385bc46d566b70de1c060c03'
        )
    return {
        'elixir_service': os.getenv('ELIXIR_SERVICE'),
        'ethereum_network': os.getenv('ETHEREUM_NETWORK'),
        'git_commit_hash': repo.head.object.hexsha,
        'contract_exchanger_url': os.getenv('CONTRACT_EXCHANGER_URL'),
        'ethereum_rpc_url': os.getenv('ETHEREUM_RPC_URL')
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
            environment_variables['ethereum_network'],
            environment_variables['contract_exchanger_url'],
            environment_variables['ethereum_rpc_url']
        )
        childchain.start()
        return
    if environment_variables['elixir_service'] == 'WATCHER':
        watcher = WatcherLauncher(
            environment_variables['git_commit_hash'],
            environment_variables['ethereum_network'],
            environment_variables['contract_exchanger_url'],
            environment_variables['ethereum_rpc_url']
        )
        watcher.start()
        return
    logging.error('Elixir service to execute not provided')


if __name__ == '__main__':
    set_logger()
    main()

