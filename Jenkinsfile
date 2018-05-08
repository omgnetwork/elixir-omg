podTemplate(
    label: 'omisego',
    containers: [
        containerTemplate(
            name: 'jnlp',
            image: 'omisegoimages/blockchain-base:1.6-otp20-stretch',
            args: '${computer.jnlpmac} ${computer.name}',
            alwaysPullImage: true
        ),
    ],
) {
    node('omisego') {
        stage('Checkout') {
            checkout scm
        }

        stage('Build') {
            sh("mix do local.hex --force, local.rebar --force")
            sh("apt-get install -y libgmp3-dev")
            withEnv(["MIX_ENV=test"]) {
                sh("mix do deps.get, deps.compile, compile")
            }
        }

        stage('Unit test Child Chain Server') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix coveralls.html --no-start --umbrella")
            }
        }

        stage('Build Contracts') {
            withEnv(["SOLC_BINARY=/home/jenkins/.py-solc/solc-v0.4.18/bin/solc"]) {
                dir("populus") {
                    sh("pip install -r requirements.txt && python -m solc.install v0.4.18 && pip install eth-utils==0.8.1 web3==3.16.5 && populus compile")
                }
            }
        }

        stage('Integration test Child Chain Server') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix test --no-start --only integration")
            }
        }

        stage('Test Watcher') {
            withEnv(["MIX_ENV=test"]) {
                dir("apps/omisego_watcher") {
                    sh("mix test --only watcher_tests")
                }
            }
        }

        stage('Lint') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix credo")
            }
        }

        stage('Cleanbuild') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix do compile --warnings-as-errors --force, test --no-start --exclude test")
            }
        }
/*
        stage('Dialyze') {
            sh("mix dialyzer --halt-exit-status")
        }
*/
    }
}
