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

        stage('Deps') {
            sh("mix do local.hex --force, local.rebar --force")
            withEnv(["MIX_ENV=test"]) {
                sh("mix do deps.get, deps.compile")
            }
        }

        stage('Build') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix compile --warnings-as-errors")
            }
        }

        stage('Test') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix coveralls.html --umbrella")
            }
        }

        stage('Lint') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix credo")
            }
        }

        stage('Dialyze') {
            withEnv(["MIX_ENV=test"]) {
                sh("mix dialyzer --halt-exit-status")
            }
        }
    }
}
