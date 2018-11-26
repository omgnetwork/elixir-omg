def label = "omisego-${UUID.randomUUID().toString()}"

podTemplate(
    label: label,
    containers: [
        containerTemplate(
            name: 'jnlp',
            image: 'omisegoimages/blockchain-base:1.6-otp20',
            args: '${computer.jnlpmac} ${computer.name}',
            alwaysPullImage: true,
            resourceRequestCpu: '1500m',
            resourceLimitCpu: '2000m',
            resourceRequestMemory: '1024Mi',
            resourceLimitMemory: '2048Mi'
        ),
        containerTemplate(
            name: 'postgresql',
            image: 'postgres:9.6.9-alpine',
            resourceRequestCpu: '250m',
            resourceLimitCpu: '800m',
            resourceRequestMemory: '512Mi',
            resourceLimitMemory: '1024Mi',
        ),
    ],
) {
    node(label) {
        def scmVars = null
        def DATABASE_URL = "postgres://postgres@localhost/omisego_test"

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
            container('postgresql') {
                sh("pg_isready -t 60 -h localhost -p 5432")
            }

            withEnv(["MIX_ENV=test", "DATABASE_URL=${DATABASE_URL}"]) {
                sh("mix test")
            }
        }

        stage('Integration test') {
           withCredentials([string(credentialsId: 'elixir-omg_coveralls', variable: 'ELIXIR_OMG_COVERALLS')]){
                withEnv(["MIX_ENV=test", "SHELL=/bin/bash", "DATABASE_URL=${DATABASE_URL}"]) {
                    sh ("""
                        set +x
                        mix coveralls.post \
                            --umbrella \
                            --include integration \
                            --include wrappers \
                            --token '${ELIXIR_OMG_COVERALLS}' \
                            --sha '${scmVars.GIT_COMMIT}' \
                    """)
                }
           }
        }

        stage('Cleanbuild') {
            withEnv(["MIX_ENV=test", "DATABASE_URL=${DATABASE_URL}"]) {
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
