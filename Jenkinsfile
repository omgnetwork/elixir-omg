podTemplate(
    label: 'omisego',
    containers: [
        containerTemplate(
            name: 'jnlp',
            image: 'gcr.io/omise-go/jenkins-slave-elixir:latest',
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

        stage('Test Child Chain Server') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix coveralls.html --no-start --umbrella")
            }
        }

        stage('Test Watcher') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix test --only watcher_tests")
            }
        }

        stage('Lint') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix credo")
            }
        }

        stage('Cleanbuild') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix compile --force --warnings-as-errors")
            }
        }
/*
        stage('Dialyze') {
            sh("mix dialyzer --halt-exit-status")
        }
*/
    }
}
