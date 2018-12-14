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
           withCredentials([string(credentialsId: 'elixir-omg_coveralls', variable: 'COVERALLS_REPO_TOKEN')]){
                withEnv(["MIX_ENV=test", "SHELL=/bin/bash", "DATABASE_URL=${DATABASE_URL}"]) {
                    sh ("""
                        BRANCH=`git describe --contains --exact-match --all HEAD | sed -r 's/^remotes\\/origin\\///'`
                        mix coveralls.post \
                            --umbrella \
                            --include integration \
                            --include wrappers \
                            --sha '${scmVars.GIT_COMMIT}' \
                            --branch \$BRANCH \
                            --message "`git log -1 --pretty=%B | head -n 1`" \
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
