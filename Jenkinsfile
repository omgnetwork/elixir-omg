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
        def scmVars = null
        stage('Checkout') {
            scmVars = checkout scm
        }

        stage('Build') {
            sh("mix do local.hex --force, local.rebar --force")
            sh("pip install -r contracts/requirements.txt")
            withEnv(["PATH+FIXPIPPATH=/home/jenkins/.local/bin/","MIX_ENV=test"]) {
                sh("mix do deps.get, deps.compile, compile")
            }
        }

        stage('Unit test') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix test")
            }
        }

        stage('Integration test') {
           withCredentials([string(credentialsId: 'elixir-omg_coveralls', variable: 'ELIXIR_OMG_COVERALLS')]){
                withEnv(["MIX_ENV=test", "SHELL=/bin/bash"]) {
                    commitMessage = sh(returnStdout: true, script: "git log -1 --pretty=%B")
                    sh ("""
                        set +x
                        mix coveralls.post \
                            --umbrella \
                            --include integration \
                            --include wrappers \
                            --token '${ELIXIR_OMG_COVERALLS}' \
                            --branch '${scmVars.GIT_BRANCH}' \
                            --sha '${scmVars.GIT_COMMIT}' \
                            --message '${commitMessage}' \
                    """)
                }
           }
        }

        stage('Cleanbuild') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix do compile --warnings-as-errors --force, test --exclude test")
            }
        }

        stage('Dialyze') {
            withEnv(["PATH+FIXPIPPATH=/home/jenkins/.local/bin/"]) {
                sh("mix dialyzer --halt-exit-status")
            }
        }

        stage('Lint') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix do credo, format --check-formatted --dry-run")
            }
        }

    }
}
