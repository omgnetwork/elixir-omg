def label = "omisego-${UUID.randomUUID().toString()}"

podTemplate(
    label: label,
    containers: [
        containerTemplate(
            name: 'jnlp',
            image: 'omisegoimages/blockchain-base:1.6-otp20',
            args: '${computer.jnlpmac} ${computer.name}',
            alwaysPullImage: true,
            resourceRequestCpu: '1750m',
            resourceLimitCpu: '2000m',
            resourceRequestMemory: '2048Mi',
            resourceLimitMemory: '2048Mi'
        ),
    ],
) {
    node(label) {
        stage('Checkout') {
            checkout scm
        }

        stage('Build') {
            sh("mix do local.hex --force, local.rebar --force")
            withEnv(["MIX_ENV=test"]) {
                sh("mix do deps.get, deps.compile, compile")
            }
        }

        stage('Unit test') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix coveralls.html --no-start --umbrella")
            }
        }

        stage('Build Contracts') {
            sh("pip install -r populus/requirements.txt")
            sh("mix deps.compile plasma_contracts")
        }

        stage('Integration test') {
           withEnv(["MIX_ENV=test", "SHELL=/bin/bash"]) {
               sh("mix test --no-start --only integration")
           }
        }

        stage('Cleanbuild') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix do compile --warnings-as-errors --force, test --no-start --exclude test")
            }
        }

        stage('Dialyze') {
            sh("mix dialyzer --halt-exit-status")
        }

        stage('Lint') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix do credo, format --check-formatted --dry-run")
            }
        }

    }
}
